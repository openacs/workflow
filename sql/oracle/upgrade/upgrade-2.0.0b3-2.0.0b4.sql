-- Add package_id parameter. With the addition of package_id to acs_objects 
-- (TIP #42) it is necessary to provide a package_id if your case objects are
-- not CR items, otherwise content_item.new freaks out.

create or replace package workflow_case_log_entry
as
  function new(
    entry_id in integer,
    case_id in integer,
    action_id in integer,
    comment in varchar,
    comment_mime_type in varchar,
    creation_user in integer,
    creation_ip in varchar,
    content_type in varchar default 'workflow_case_log_entry',
    package_id in integer
    ) return integer;

end workflow_case_log_entry;
/
show errors

create or replace package body workflow_case_log_entry
as
   function new(
    entry_id in integer,
    case_id in integer,
    action_id in integer,
    comment in varchar,
    comment_mime_type in varchar,
    creation_user in integer,
    creation_ip in varchar,
    content_type in varchar default 'workflow_case_log_entry',
    package_id in integer
    ) return integer
  is
    v_name                        varchar2(4000); -- XXX aufflick fix this
    v_action_short_name           varchar2(4000);
    v_action_pretty_past_tense    varchar2(4000);
    v_case_object_id              integer;
    v_item_id                     integer;
    v_revision_id                 integer;
    v_package_id                  integer;
  begin
    select short_name, pretty_past_tense
    into   v_action_short_name, v_action_pretty_past_tense
    from   workflow_actions
    where  action_id = new.action_id;
    -- use case object as context_id
    select object_id
    into   v_case_object_id
    from   workflow_cases
    where  case_id = new.case_id;

    -- build the unique name
    if entry_id is not null then
        v_item_id := entry_id;
    else
        select acs_object_id_seq.nextval into v_item_id from dual;
    end if;
    v_name := v_action_short_name || ' ' || v_item_id;

    -- get the package_id
    if package_id is not null then
        v_package_id := package_id;
    else
        -- this will return null if the app stores the package_id
        -- in a package-specific table instead of acs_objects
        v_package_id := acs_object__package_id(v_case_object_id);
    end if;

    v_item_id := content_item.new (
        item_id        => v_item_id,
        name            => v_name,
        parent_id       => v_case_object_id,
        title           => v_action_pretty_past_tense,
        creation_date   => sysdate(),
        creation_user   => creation_user,
        context_id      => v_case_object_id,
        creation_ip     => creation_ip,
        is_live         => 't',
        mime_type       => comment_mime_type,
        text            => comment,
        storage_type    => 'text',
        item_subtype    => 'content_item',
        content_type    => content_type,
        package_id      => package_id
    );

    -- insert the row into the single-column entry revision table
    v_revision_id := content_item.get_live_revision (v_item_id);

    insert into workflow_case_log_rev (entry_rev_id)
    values (v_revision_id);

    -- insert into workflow-case-log
    -- raise_application_error(-20000, 'about to insert ' || v_item_id || ',' || new.case_id || ',' || new.action_id);
    insert into workflow_case_log (entry_id, case_id, action_id)
    values (v_item_id, new.case_id, new.action_id);

    -- return id of newly created item
    return v_item_id;
  end new;

end workflow_case_log_entry;
/
show errors
