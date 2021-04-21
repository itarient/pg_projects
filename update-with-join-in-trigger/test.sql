-- Test #1: check trigger firred.
-- Detail:
-- SELECT origin values
-- INSERT four rows into the 'inserted_table' with some 
-- legal values for 'linked_id' and 'linked_value'.
-- SELECT new values
set search_path to update_with_join_in_trigger;

select updated_field from updated_table where id = 1
\gset orig1_
select updated_field from updated_table where id = 2
\gset orig2_
\echo BEFORE INSERT :orig1_updated_field :orig2_updated_field

insert into inserted_table (id, linked_id, linked_field) values
(1, 1, 1),
(2, 2, 2),
(3, 3, 3),
(4, 4, 4);

select updated_field from updated_table where id = 1
\gset new1_
select updated_field from updated_table where id = 2
\gset new2_

-- Its should be the following:
-- (1, 1, 1) => linked_ids = 1, 2 =>
-- linked_id=1 => 1000 -= 1 * 50 => 950 
-- linked_id=2 => 2000 -= 1 * 100 => 1900
-- (2, 2, 2) => linked_ids = 1, 2 =>
-- linked_id=1 => 950 -= 2 * 100 => 750
-- linked_id=2 => 1900 -= 2 * 200 => 1500
-- (3, 3, 3) => linked_ids = 1
-- linked_id=1 750 -= 3 * 500 => -750
-- (4, 4, 4) => linked_ids = 2
-- linked_id=2 1500 -= 4 * 500 => -500
\echo AFTER INSERT :new1_updated_field :new2_updated_field

select
    (:orig1_updated_field - (1 * 50 + 2 * 100 + 3 * 500) = :new1_updated_field)
    and
    (:orig2_updated_field - (1 * 100 + 2 * 200 + 4 * 500) = :new2_updated_field) as test_ok
\gset

\if :test_ok
    \echo TEST - OK!
\else
    \echo TEST - FAILED!
\endif
