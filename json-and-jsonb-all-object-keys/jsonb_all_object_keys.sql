create or replace function jsonb_all_object_keys(jsonb)
    returns setof text
    language sql
as $body$
with recursive object_hierarchy(obj_name, obj_data) as
(
    select 
        keys.obj_name,
        case jsonb_typeof(root_objs.obj_data -> keys.obj_name)
            when 'object' then root_objs.obj_data -> keys.obj_name
            else null
        end
    from 
        (values ($1)) as root_objs(obj_data),
        jsonb_object_keys(root_objs.obj_data) as keys(obj_name)
union all
    select
        keys.obj_name,
        case jsonb_typeof(sub_objs.obj_data -> keys.obj_name)
            when 'object' then sub_objs.obj_data -> keys.obj_name
            else null
        end
    from
        object_hierarchy as sub_objs,
        jsonb_object_keys(sub_objs.obj_data) as keys(obj_name)
    where
        sub_objs.obj_data is not null
)
select obj_name from object_hierarchy;
$body$;
