<?xml version="1.0"?>
<queryset>
  <rdbms><type>oracle</type><version>8.1.6</version></rdbms>

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
      from   workflows w,
             workflow_initial_action wia,
             workflow_actions a
      where  w.workflow_id = :workflow_id
        and  wia.workflow_id = w.workflow_id (+)
        and  a.action_id = wia.action_id (+)
    </querytext>
  </fullquery>

  <fullquery name="workflow::new.do_insert">
    <querytext>
        begin
        :1 := workflow.new (
            short_name => :short_name,
            pretty_name => :pretty_name,
            package_key => :package_key,            
            object_id => :object_id,
            object_type => :object_type,
            creation_user => :creation_user,
            creation_ip => :creation_ip,
            context_id => :context_id
        );
        end;
    </querytext>
  </fullquery>

  <fullquery name="workflow::delete.do_delete">
    <querytext>
        begin
            :1 := workflow.del(:workflow_id);
        end;
    </querytext>
  </fullquery>
 
  <fullquery name="workflow::callback_insert.select_sort_order">
    <querytext>
        select nvl(max(sort_order),0) + 1
        from   workflow_callbacks
        where  workflow_id = :workflow_id
    </querytext>
  </fullquery>

</queryset>
