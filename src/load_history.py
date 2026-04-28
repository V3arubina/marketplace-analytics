import pandas as pd
from datetime import date, timedelta
from sqlalchemy import text

from api_client import get_data_by_date
from db import get_engine


def load_one_day(source_date: str, engine) -> int:
    data = get_data_by_date(source_date)

    if not data:
        print(f"[{source_date}] Нет данных")
        return 0

    df = pd.DataFrame(data)

    df["purchase_date"] = pd.to_datetime(df["purchase_datetime"]).dt.date
    df["purchase_time_seconds"] = df["purchase_time_as_seconds_from_midnight"].astype(
        int
    )
    df["purchase_datetime"] = pd.to_datetime(df["purchase_datetime"])
    df["load_date"] = pd.Timestamp.today().date()
    df["source_date"] = pd.to_datetime(source_date).date()

    df_final = df[
        [
            "client_id",
            "gender",
            "purchase_date",
            "purchase_time_seconds",
            "purchase_datetime",
            "product_id",
            "quantity",
            "price_per_item",
            "discount_per_item",
            "total_price",
            "load_date",
            "source_date",
        ]
    ].copy()

    with engine.begin() as conn:
        conn.execute(
            text("DELETE FROM purchases WHERE source_date = :source_date"),
            {"source_date": source_date},
        )

    df_final.to_sql(
        "purchases", con=engine, if_exists="append", index=False, method="multi"
    )

    print(f"[{source_date}] Загружено строк: {len(df_final)}")
    return len(df_final)


def main():
    engine = get_engine()

    start_date = date(2023, 1, 1)
    end_date = date(2023, 12, 31)

    current_date = start_date
    total_rows = 0

    while current_date <= end_date:
        source_date = current_date.isoformat()
        try:
            total_rows += load_one_day(source_date, engine)
        except Exception as e:
            print(f"[{source_date}] Ошибка: {e}")
        current_date += timedelta(days=1)

    print(f"Готово. Всего загружено строк: {total_rows}")


if __name__ == "__main__":
    main()
