#!/usr/bin/env python3
"""
Remote signing client for UEFI Secure Boot components.
Sends unsigned binaries to a signing server and receives signed versions.
"""

import sys
import os
import argparse
import json
import time
import hashlib
import subprocess
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError


def calculate_hash(filepath, algorithm='sha256'):
    """Calculate hash of a file."""
    h = hashlib.new(algorithm)
    with open(filepath, 'rb') as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()


def sign_remote(unsigned_file, signed_file, config):
    """Send file to remote signing server and receive signed version."""
    
    server_url = config['server_url']
    auth_method = config['auth_method']
    component_type = config['component_type']
    timeout = int(config['timeout'])
    retries = int(config['retries'])
    retry_delay = int(config['retry_delay'])
    
    # Calculate hash of unsigned file for verification
    unsigned_hash = calculate_hash(unsigned_file)
    
    # Read unsigned binary
    with open(unsigned_file, 'rb') as f:
        binary_data = f.read()
    
    # Prepare request payload
    payload = {
        'component_type': component_type,
        'filename': os.path.basename(unsigned_file),
        'hash_algorithm': 'sha256',
        'unsigned_hash': unsigned_hash,
    }
    
    # Create multipart/form-data request
    boundary = '----WebKitFormBoundary' + os.urandom(16).hex()
    body = []
    
    # Add JSON metadata
    body.append(f'--{boundary}'.encode())
    body.append(b'Content-Disposition: form-data; name="metadata"')
    body.append(b'Content-Type: application/json')
    body.append(b'')
    body.append(json.dumps(payload).encode())
    
    # Add binary file
    body.append(f'--{boundary}'.encode())
    body.append(f'Content-Disposition: form-data; name="file"; filename="{os.path.basename(unsigned_file)}"'.encode())
    body.append(b'Content-Type: application/octet-stream')
    body.append(b'')
    body.append(binary_data)
    body.append(f'--{boundary}--'.encode())
    body.append(b'')
    
    body_bytes = b'\r\n'.join(body)
    
    # Prepare headers
    headers = {
        'Content-Type': f'multipart/form-data; boundary={boundary}',
        'Content-Length': str(len(body_bytes)),
    }
    
    # Add authentication
    if auth_method == 'token':
        token = config.get('auth_token', '')
        if token:
            headers['Authorization'] = f'Bearer {token}'
        else:
            print("ERROR: Token-based auth enabled but UEFI_SIGNING_AUTH_TOKEN not set", file=sys.stderr)
            return 1
    
    # Retry loop
    for attempt in range(retries):
        try:
            print(f"Sending {unsigned_file} to signing server (attempt {attempt + 1}/{retries})...")
            
            req = Request(server_url, data=body_bytes, headers=headers)
            
            # Handle client certificates for cert-based auth
            if auth_method == 'cert':
                # Python's urllib doesn't support client certs well, use curl
                return sign_remote_curl(unsigned_file, signed_file, config)
            
            with urlopen(req, timeout=timeout) as response:
                if response.status == 200:
                    signed_data = response.read()
                    
                    # Write signed binary
                    with open(signed_file, 'wb') as f:
                        f.write(signed_data)
                    
                    print(f"Successfully received signed binary: {signed_file}")
                    
                    # Verify if requested
                    if config.get('verify', '1') == '1':
                        if verify_signature(signed_file):
                            print("Signature verification: PASSED")
                            return 0
                        else:
                            print("ERROR: Signature verification FAILED", file=sys.stderr)
                            return 1
                    
                    return 0
                else:
                    print(f"ERROR: Server returned status {response.status}", file=sys.stderr)
                    
        except HTTPError as e:
            print(f"HTTP Error: {e.code} - {e.reason}", file=sys.stderr)
            if e.code == 401:
                print("Authentication failed. Check UEFI_SIGNING_AUTH_TOKEN", file=sys.stderr)
                return 1
            
        except URLError as e:
            print(f"URL Error: {e.reason}", file=sys.stderr)
            
        except Exception as e:
            print(f"Error: {str(e)}", file=sys.stderr)
        
        # Retry with delay
        if attempt < retries - 1:
            print(f"Retrying in {retry_delay} seconds...")
            time.sleep(retry_delay)
    
    print(f"ERROR: Failed to sign after {retries} attempts", file=sys.stderr)
    return 1


def sign_remote_curl(unsigned_file, signed_file, config):
    """Use curl for signing with client certificates."""
    
    server_url = config['server_url']
    component_type = config['component_type']
    timeout = config['timeout']
    client_cert = config.get('client_cert', '')
    client_key = config.get('client_key', '')
    retries = int(config['retries'])
    
    unsigned_hash = calculate_hash(unsigned_file)
    
    curl_cmd = [
        'curl',
        '-X', 'POST',
        '-F', f'file=@{unsigned_file}',
        '-F', f'metadata={{"component_type":"{component_type}","hash_algorithm":"sha256","unsigned_hash":"{unsigned_hash}"}}',
        '--max-time', timeout,
        '--retry', str(retries - 1),
        '--retry-delay', config['retry_delay'],
        '-o', signed_file,
    ]
    
    if client_cert and client_key:
        curl_cmd.extend(['--cert', client_cert, '--key', client_key])
    
    if config['auth_method'] == 'token' and config.get('auth_token'):
        curl_cmd.extend(['-H', f'Authorization: Bearer {config["auth_token"]}'])
    
    curl_cmd.append(server_url)
    
    print(f"Signing with curl: {' '.join(curl_cmd[:5])}...")
    result = subprocess.run(curl_cmd, capture_output=True)
    
    if result.returncode == 0:
        print(f"Successfully received signed binary: {signed_file}")
        if config.get('verify', '1') == '1':
            if verify_signature(signed_file):
                print("Signature verification: PASSED")
                return 0
            else:
                print("ERROR: Signature verification FAILED", file=sys.stderr)
                return 1
        return 0
    else:
        print(f"ERROR: curl failed: {result.stderr.decode()}", file=sys.stderr)
        return 1


def verify_signature(signed_file):
    """Verify the signature on a signed EFI binary."""
    try:
        # Use sbverify if available
        result = subprocess.run(
            ['sbverify', '--list', signed_file],
            capture_output=True,
            text=True
        )
        return result.returncode == 0
    except FileNotFoundError:
        # sbverify not available, skip verification
        print("Warning: sbverify not found, skipping signature verification")
        return True


def main():
    parser = argparse.ArgumentParser(description='Remote signing client for UEFI Secure Boot')
    parser.add_argument('unsigned_file', help='Path to unsigned binary')
    parser.add_argument('signed_file', help='Path to write signed binary')
    parser.add_argument('--server-url', required=True, help='Signing server URL')
    parser.add_argument('--auth-method', default='token', choices=['token', 'cert', 'none'],
                       help='Authentication method')
    parser.add_argument('--auth-token', help='Authentication token')
    parser.add_argument('--client-cert', help='Client certificate for cert-based auth')
    parser.add_argument('--client-key', help='Client key for cert-based auth')
    parser.add_argument('--component-type', default='kernel', help='Component type identifier')
    parser.add_argument('--timeout', default='300', help='Request timeout in seconds')
    parser.add_argument('--retries', default='3', help='Number of retry attempts')
    parser.add_argument('--retry-delay', default='5', help='Delay between retries in seconds')
    parser.add_argument('--verify', default='1', choices=['0', '1'], help='Verify signature after signing')
    
    args = parser.parse_args()
    
    config = {
        'server_url': args.server_url,
        'auth_method': args.auth_method,
        'auth_token': args.auth_token,
        'client_cert': args.client_cert,
        'client_key': args.client_key,
        'component_type': args.component_type,
        'timeout': args.timeout,
        'retries': args.retries,
        'retry_delay': args.retry_delay,
        'verify': args.verify,
    }
    
    return sign_remote(args.unsigned_file, args.signed_file, config)


if __name__ == '__main__':
    sys.exit(main())
