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

create function workflow__delete (integer)
returns integer as '
declare
  delete_workflow_id            alias for $1;
begin
  select acs_object__delete(delete_workflow_id);

  return 0; 
end;' language 'plpgsql';


-- Function for creating a workflow
create or replace function workflow__new (
    varchar, -- short_name
    varchar, -- pretty_name
    varchar, -- package_key
    integer, -- object_id
    varchar, -- object_type
    integer, -- creation_user
    varchar, -- creation_ip
    integer  -- context_id
)
returns integer as '
declare
    p_short_name            alias for $1;
    p_pretty_name           alias for $2;
    p_package_key           alias for $3;
    p_object_id             alias for $4;
    p_object_type           alias for $5;
    p_creation_user         alias for $6;
    p_creation_ip           alias for $7;
    p_context_id            alias for $8;
  
    v_workflow_id           integer;
begin
    -- Instantiate the ACS Object super type with auditing info
    v_workflow_id  := acs_object__new(null,
                                      ''workflow_lite'',
                                      now(),
                                      p_creation_user,
                                      p_creation_ip,
                                      p_context_id,
                                      ''t'');

    -- Insert workflow specific info into the workflows table
    insert into workflows
           (workflow_id, short_name, pretty_name, package_key, object_id, object_type)
       values
           (v_workflow_id, p_short_name, p_pretty_name, p_package_key, p_object_id, p_object_type);
            

   return v_workflow_id;
end;
' language 'plpgsql';




-- Function for getting the pretty state of a case
create or replace function workflow_case__get_pretty_state (
    varchar, -- workflow_short_name
    integer  -- object_id
)
returns varchar as '
declare
    p_workflow_short_name   alias for $1;
    p_object_id             alias for $2;
  
    v_state_pretty          varchar;
begin
   select s.pretty_name
   into   v_state_pretty
   from   workflows w,
          workflow_cases c,
          workflow_case_fsm cfsm,
          workflow_fsm_states s
   where  w.short_name = p_workflow_short_name
   and    c.object_id = p_object_id
   and    c.workflow_id = w.workflow_id
   and    cfsm.case_id = c.case_id
   and    s.state_id = cfsm.current_state;

   return v_state_pretty;
end;
' language 'plpgsql';

create function workflow_activity_log__new (integer, --case_id
                                            integer, --action_id
                                            varchar  -- comment_format
                                           ) returns integer as '
declare
    new__case_id           alias for $1;
    new__action_id         alias for $2;
    new__comment_format    alias for $3;
    
        
    v_item_id		   cr_items.item_id%TYPE;
    v_revision_id	   cr_revisions.revision_id%TYPE;
begin

    v_item_id := content_item__new (
      new__name,
      new__parent_id,
      new__item_id,
      new__locale,
      new__creation_date,
      new__creation_user,	
      new__context_id,
      new__creation_ip,
      ''content_item'',
      new__content_type,
      null,
      null,
      null,
      null,
      null
    );

    v_revision_id := content_revision__new (
      new__title,
      new__description,
      new__publish_date,
      new__mime_type,
      new__nls_language,
      null,
      v_item_id,
      new__revision_id,
      new__creation_date,
      new__creation_user,
      new__creation_ip

    );

    insert into workflow_case_log
             (entry_id, case_id, action_id, comment_format)
      values (v_revision_id, new__case_id, new__action_id, new__comment_format);

    PERFORM content_item__set_live_revision (v_revision_id);        

end; ' language 'plpgsql';
