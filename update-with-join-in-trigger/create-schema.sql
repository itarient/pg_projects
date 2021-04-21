create schema if not exists update_with_join_in_trigger;
set search_path to update_with_join_in_trigger;

create table if not exists updated_table
(
    id integer,
    updated_field integer
);

create table if not exists linked_table
(
    id integer,
    updated_id integer,
    value_field integer
);

create table if not exists inserted_table
(
    id integer,
    linked_id integer,
    linked_field integer
);

insert into updated_table (id, updated_field) values
(1, 1000),
(2, 2000);

insert into linked_table (id, updated_id, value_field) values
(1, 1, 50),
(1, 2, 100),
(2, 1, 100),
(2, 2, 200),
(3, 1, 500),
(4, 2, 500);

create or replace function trigger_func() 
returns trigger
language plpgsql
as $body$
begin
    if new.linked_id is not null 
    then
        update updated_table as ut
            set updated_field = updated_field - new.linked_field * lt.value_field
            from linked_table as lt
            where ut.id = lt.updated_id and lt.id = new.linked_id;
    end if;
    return new;
end;
$body$;

create trigger inserted_table_trg1 
    after insert on inserted_table
    for each row
    execute function trigger_func();
