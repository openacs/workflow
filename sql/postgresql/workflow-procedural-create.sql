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

-- Function for creating a workflow
create function workflow__new (varchar, -- short_name
                               varchar, -- pretty_name
                               integer, -- object_id
                               varchar, -- object_type
                               integer, -- creation_user
                               integer, -- creation_ip
                               integer  -- context_id
                              )
returns integer as '
declare
        p_short_name            alias for $1;
        p_pretty_name           alias for $2;
        p_object_id             alias for $3;
        p_object_type           alias for $4;
        p_creation_user         alias for $5;
        p_creation_ip           alias for $6;
        p_context_id            alias for $7;

        v_workflow_id           integer;
begin
        -- Instantiate the ACS Object super type with auditing info
        v_workflow_id  := acs_object__new(null,
                                          ''workflow_new'',
                                          now(),
                                          p_creation_user,
                                          p_creation_ip,
                                          p_context_id,
                                          ''t'');

        -- Insert workflow specific info into the workflows table
        insert into workflows
               (workflow_id, short_name, pretty_name, object_id, object_type)
           values
               (v_workflow_id, p_short_name, p_pretty_name, p_object_id, p_object_type)        
                
end;
' language 'plpgsql';
