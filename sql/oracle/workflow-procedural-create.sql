-- Procedural database code for the workflow package, a package in the OpenACS system.
--
-- @author Lars Pind (lars@collaboraid.biz)
-- @author Peter Marklund (peter@collaboraid.biz)
--
-- This is free software distributed under the terms of the GNU Public
-- License.  Full text of the license is available from the GNU Project:
-- http://www.fsf.org/copyleft/gpl.html

---------------------------------
-- Workflow level, Generic Model
---------------------------------

create or replace package workflow 
as 
  function delete(
    delete_workflow_id in integer
    ) return integer;

  function new(
    short_name  in varchar,
    pretty_name in varchar,
    package_key in varchar,
    object_id   in integer,
    object_type in varchar,
    creation_user in integer,
    creation_ip   in varchar,
    context_id    in integer
  ) return integer;

end workflow;
/
show errors

-- package bodies

create or replace package body workflow
as 
  function delete(
    delete_workflow_id in integer
  ) return integer 
  is
  begin
    acs_object.delete(delete_workflow_id);
    return 0;
  end delete;
 

  -- Function for creating a workflow
  function new(
    short_name    in varchar, 
    pretty_name   in varchar,
    package_key   in varchar,
    object_id     in integer,
    object_type   in varchar,
    creation_user in integer, 
    creation_ip   in varchar,
    context_id    in integer
    ) return integer
    is  
      v_workflow_id integer;
  begin 
     -- Instantiate the ACS Object super type with auditing info
     v_workflow_id  := acs_object.new(
                          object_id => null,
                          object_type => 'workflow_lite',
                          creation_date => sysdate(),
                          creation_user => creation_user,
                          creation_ip   => creation_ip,
                          context_id    => context_id
                          );

    -- Insert workflow specific info into the workflows table
    insert into workflows 
           (workflow_id, short_name, pretty_name, package_key, object_id, object_type)
    values
           (v_workflow_id, short_name, pretty_name, package_key, object_id, object_type);
            
    return v_workflow_id;
  end new;

end workflow;
/
show errors

create or replace package workflow_case
as function get_pretty_state(
   workflow_short_name in varchar,
   object_id in integer
   ) return varchar;

end workflow_case;
/
show errors

-- Function for getting the pretty state of a case
create or replace package body workflow_case
as 
  function get_pretty_state(
    workflow_short_name in varchar,
    object_id in integer
  ) return varchar
  is 
    v_state_pretty varchar(4000);
    v_object_id integer;
  begin
   v_object_id := object_id;   

   select s.pretty_name
   into   v_state_pretty
   from   workflows w,
          workflow_cases c,
          workflow_case_fsm cfsm,
          workflow_fsm_states s
   where  w.short_name = workflow_short_name
   and    c.object_id = v_object_id
   and    c.workflow_id = w.workflow_id
   and    cfsm.case_id = c.case_id
   and    s.state_id = cfsm.current_state;

   return v_state_pretty;

   end get_pretty_state;    

end workflow_case;
/
show errors

-- --create or replace package workflow_activity_log
-- --as 
--   function new(
--     case_id in integer,
--     action_id in integer,
--     comment_format in varchar
--   ) return integer;

-- end workflow_activity_log;
-- /
-- show errors

-- create or replace package body workflow_activity_log 
-- as 
--   function new(
--     case_id in integer,
--     action_id in integer,
--     comment_format in varchar
--   ) return integer 
--   is
--     v_item_id		   cr_items.item_id%TYPE;
--     v_revision_id	   cr_revisions.revision_id%TYPE;
--   begin
--     v_item_id := content_item.new (
--        name,
--        parent_id,
--        item_id,
--        locale,
--        creation_date,
--        creation_user,	
--        context_id,
--        creation_ip,
--        'content_item',
--         content_type,
--         null,
--         null,
--         null,
--         null,
--         null
--        );

--     v_revision_id := content_revision.new (
--       title,
--       description,
--       publish_date,
--       mime_type,
--       nls_language,
--       null,
--       v_item_id,
--       revision_id,
--       creation_date,
--       creation_user,
--       creation_ip
--     );

--      insert into workflow_case_log
--              (entry_id, case_id, action_id, comment_format)
--       values (v_revision_id, case_id, action_id, comment_format);

--      content_item.set_live_revision (v_revision_id);  
      
--     end new;

-- end workflow_activity_log;
-- /
--show errors

