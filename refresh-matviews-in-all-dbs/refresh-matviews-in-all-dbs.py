#!/usr/bin/env python3

import psycopg2
import datetime


class refresh_matview_list_actions:
    before_refresh_matview_list = None
    before_refresh_matview = None
    after_refresh_matview = None
    after_refresh_matview_list = None

class timing_object:
    def __init__(self) -> None:
        self.start_time = None
        self.stop_time = None

    def start(self) -> None:
        self.start_time = datetime.datetime.now()

    def stop(self) -> None:
        self.stop_time = datetime.datetime.now()

    def diff(self) -> float:
        if self.start_time is None or self.stop_time is None or self.start_time > self.stop_time:
            raise RuntimeError()
        return self.stop_time - self.start_time

def get_database_list(cur) -> list:
    """Return a list of database names in current connection"""
    cur.execute("select datname from pg_database order by 1")
    return cur.fetchall()

def get_matview_list(cur) -> list:
    """
    Return a list of materialized view full-qualified names
    in current connection
    """
    ret = []

    cur.execute("select quote_ident(schemaname), quote_ident(matviewname) from pg_matviews order by 1, 2")
    for rec in cur:
        ret.append(rec[0] + "." + rec[1])

    return ret

def refresh_matview(cur, matview_name) -> None:
    """Refresh the specified materialized view"""
    query_str = cur.mogrify("refresh materialized view {}".format(matview_name))
    cur.execute(query_str)

def refresh_matview_list(conn,
                         matview_names,
                         single_transaction,
                         actions) -> None:
    """Refresh a list of materialized views"""
    cur = None

    if actions.before_refresh_matview_list:
        actions.before_refresh_matview_list(matview_names)

    if single_transaction:
        cur = conn.cursor()

    for matview_name in matview_names:
        if not single_transaction:
            cur = conn.cursor()

        if actions.before_refresh_matview:
            actions.before_refresh_matview(matview_name)

        refresh_matview(cur, matview_name)

        if actions.after_refresh_matview:
            actions.after_refresh_matview(matview_name)

        if not single_transaction:
            conn.commit()

    if single_transaction:
        conn.commit()

    if actions.after_refresh_matview_list:
        actions.after_refresh_matview_list(matview_names)


if __name__ == '__main__':
    single_transaction = False
    actions = refresh_matview_list_actions()
    all_timings = timing_object()
    database_timings = timing_object()
    matview_timings = timing_object()

    def on_before_refresh_matview_list(matview_names):
        database_timings.start()

    def on_before_refresh_matview(matview_name):
        matview_timings.start()
        print("\tRefreshing {0} ... ".format(matview_name), end='')

    def on_after_refresh_matview(matview_name):
        matview_timings.stop()
        print("{0}".format(matview_timings.diff()))

    def on_after_refresh_matview_list(matview_names):
        database_timings.stop()

    actions.before_refresh_matview_list = on_before_refresh_matview_list
    actions.before_refresh_matview = on_before_refresh_matview
    actions.after_refresh_matview = on_after_refresh_matview
    actions.after_refresh_matview_list = on_after_refresh_matview_list

    print("Refresh all materialized views in all databases")

    dbs = []
    with psycopg2.connect() as conn:
        print("Getting database list ... ", end='')
        with conn.cursor() as cur:
            dbs = get_database_list(cur)
        print("found {0} database{1} (including templates)".format(len(dbs), ("s" if len(dbs) > 0 else "")))
    print()

    all_timings.start()

    for db_rec in dbs:
        db = db_rec[0]

        print("Processing database {0} ... ".format(db), end='')

        if db == "template0" or db == "template1":
            print("skipping")
            print()
            continue

        with psycopg2.connect("dbname={}".format(db)) as conn:
            with conn.cursor() as cur:
                matview_names = get_matview_list(cur)
            print("found {0} materialized view{1}".format(len(matview_names),
                                                          ("s" if len(matview_names) > 0 else "")))

            refresh_matview_list(conn, matview_names,single_transaction, actions)
            print("Database time elapsed = {0}".format(database_timings.diff()))
            print()

    all_timings.stop()
    print("All time elapsed = {0}".format(all_timings.diff()))
