<?xml version="1.0"?>
<queryset>
  <rdbms><type>postgresql</type><version>7.2</version></rdbms>

  <fullquery name="workflow::get_not_cached.workflow_info">
    <querytext>
      select w.workflow_id,
             w.short_name,
             w.pretty_name,
             w.object_id,
             w.package_key,
             w.object_type,
             a.short_name as initial_action,
             a.action_id as initial_action_id
      from   workflows w left outer join
             workflow_initial_action wia 
               on (w.workflow_id = wia.workflow_id) left outer join
             workflow_actions a 
               on (a.action_id = wia.action_id)
      where  w.workflow_id = :workflow_id
    </querytext>
  </fullquery>


  <fullquery name="workflow::new.do_insert">
    <querytext>
        select workflow__new (
            :short_name,
            :pretty_name,
            :package_key,            
            :object_id,
            :object_type,
            :creation_user,
            :creation_ip,
            :context_id
        );
    </querytext>
  </fullquery>

  <fullquery name="workflow::delete.do_delete">
    <querytext>
        select workflow__delete(:workflow_id);
    </querytext>
  </fullquery>
  
  <fullquery name="workflow::callback_insert.select_sort_order">
    <querytext>
        select coalesce(max(sort_order),0) + 1
        from   workflow_callbacks
        where  workflow_id = :workflow_id
    </querytext>
  </fullquery>

 </queryset>
