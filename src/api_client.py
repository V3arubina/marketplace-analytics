import requests
from time import sleep

URL = "http://final-project.simulative.ru/data"


def get_data_by_date(date_str: str):
    for attempt in range(3):
        try:
            response = requests.get(URL, params={"date": date_str}, timeout=30)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"[{date_str}] Попытка {attempt + 1}/3 не удалась: {e}")
            if attempt < 2:
                sleep(5)

    raise RuntimeError(f"API недоступен для {date_str} после 3 попыток")
