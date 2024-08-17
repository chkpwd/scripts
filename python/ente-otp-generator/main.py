from urllib.parse import urlparse, parse_qs, unquote
from collections import defaultdict
import pyotp
import click
import json
import pathlib


DB_FILE = pathlib.Path.home() /".local/share/ente-totp/db.json"

@click.group()
def cli():
   pass

@cli.command('import')
@click.argument("file", type=click.Path(exists=True))
def import_file(file):
    secret_dict = defaultdict(list) # uses parameterless lambda to create a new list for each key

    for service_name, username, secret in parse_secrets(file):
        secret_dict[service_name].append((username, secret))

    # Create directory if it doesn't exist
    DB_FILE.parent.mkdir(parents=True, exist_ok=True)

    with DB_FILE.open("w") as json_file:
        json.dump(secret_dict, json_file, indent=2)

    print("Database created.")

def parse_secrets(file_path="secrets.txt"):
    secrets_list = []
    
    with open(file_path, "r") as secrets_file:
        for line in secrets_file:
            line = line.strip()
            if line:
                parsed_url = urlparse(line)
                if parsed_url.scheme == "otpauth":
                    path_items = unquote(parsed_url.path).strip('/').split(':', 1)
                    if len(path_items) == 2:
                        service_name, username = path_items[0], path_items[1]
                    else:
                        service_name, username = path_items[0].strip(':'), ""
                    query_params = parse_qs(parsed_url.query)
                    secret = query_params.get("secret", [None])[0]
                    if secret:
                        secrets_list.append((service_name, username, secret))
    
    return secrets_list

@cli.command('get')
@click.argument('secret_id')
@click.option("-j","json_output", is_flag=True)
def generate_totp(secret_id, json_output):
    with open(DB_FILE, "r") as file:
        data = json.load(file)
    totp_data = None
    for service_name, service_data in data.items():
        if secret_id.lower() == service_name.lower():
            totp_data = service_name, service_data
            break

    if totp_data:
        service_name, service_data = totp_data
        if not json_output:
            print(service_name)
            for username, secret in service_data:
                totp = pyotp.TOTP(secret)

                # Generate the current TOTP code
                current_code = totp.now()

                print(f'\t{username}: {current_code}')
        else:
            json_data = []
            for username, secret in service_data:
                totp = pyotp.TOTP(secret)

                # Generate the current TOTP code
                current_code = totp.now()
                json_data.append({
                    "name": username,
                    "totp": current_code
                })

            print(json.dumps(json_data))
    else:
        print("No matching service")
        return
   

if __name__ == "__main__":
    cli()

