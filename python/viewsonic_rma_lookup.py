from html.parser import HTMLParser
import requests


class ViewSonicParser(HTMLParser):
    def handle_data(self, data):
        # Grab only the data we need
        if "Status:" in data:
            print(data)
        elif "Last Status Date:" in data:
            print(data)


def get_rma_status(rma_number: str):
    """Get the RMA status from the ViewSonic website."""

    base_url = "https://www.viewsonic.com/rmalookup.php"
    url = f"{base_url}"
    response = requests.post(url, data={"rma_no": rma_number}, timeout=10)

    p = ViewSonicParser()
    p.feed(response.text)
    p.close()

    return p


get_rma_status(rma_number="R1186499-1")
