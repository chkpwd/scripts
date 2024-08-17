#! /usr/bin/env python3

from html.parser import HTMLParser
import argparse
import requests
import datetime

arg = argparse.ArgumentParser()
arg.add_argument("--rma", type=str, help="RMA number to look up")
arg.add_argument("--webhook", type=str, help="Webhook URL to send message to")
args = arg.parse_args()


class ViewSonicParser(HTMLParser):

    def __init__(self):
        super().__init__()
        self.data = []
        self.capture = False

    def handle_starttag(self, tag, attrs):
        if tag == 'p':
            for attr in attrs:
                if attr == ('class', 'text-center'):
                    self.capture = True

    def handle_endtag(self, tag):
        if tag == 'p':
            self.capture = False

    def handle_data(self, data):
        if self.capture and 'Status:' in data:
            self.data.append(data)


def get_rma_status(rma_number: str):
    """Get the RMA status from the ViewSonic website."""

    base_url = "https://www.viewsonic.com/rmalookup.php"
    url = f"{base_url}"
    html = requests.post(url, data={"rma_no": rma_number}, timeout=10)

    p = ViewSonicParser()
    p.feed(html.text)

    return p.data


def send_webhook(webhook_url: str, message: str):
    """Send a simple message to a Discord webhook."""

    url = webhook_url

    embed = {
        "description": f"RMA: {args.rma}\n {message}!",
        "title": "RMA Status"
    }

    data = {
        "username": "ViewSonic Bot",
        "embeds": [embed],
    }

    return requests.post(url=url, json=data, timeout=10)


def main():
    """Main function."""

    current_time = datetime.datetime.now().strftime("%m/%d/%Y %H:%M:%S")
    rma_status = get_rma_status(args.rma)

    if "Awaiting Fulfillment" in rma_status[0]:
        print(current_time, f"- {rma_status[0]}")
    else:
        send_webhook(args.webhook, rma_status[0])


if __name__ == '__main__':
    main()
