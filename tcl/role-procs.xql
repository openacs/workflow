<?xml version="1.0"?>
<queryset>

  <fullquery name="workflow::role::new.select_sort_order_p">
    <querytext>
        select count(*)
        from   workflow_roles
        where  workflow_id = :workflow_id
        and    sort_order = :sort_order
    </querytext>
  </fullquery>

  <fullquery name="workflow::role::new.update_sort_order">
    <querytext>
        update workflow_roles
        set    sort_order = sort_order + 1
        where  workflow_id = :workflow_id
        and    sort_order >= :sort_order
    </querytext>
  </fullquery>

  <fullquery name="workflow::role::insert.do_insert">
    <querytext>
        insert into workflow_roles
                (role_id, workflow_id, short_name, pretty_name, sort_order)
             values
                (:role_id, :workflow_id, :short_name, :pretty_name, :sort_order)
    </querytext>
  </fullquery>

  <fullquery name="workflow::role::get_id.select_role_id">
    <querytext>
        select role_id 
        from   workflow_roles 
        where  workflow_id = :workflow_id 
        and    short_name = :short_name
    </querytext>
  </fullquery>

  <fullquery name="workflow::role::get.role_info">
    <querytext>
        select role_id,
               workflow_id,
               short_name,
               pretty_name,
               sort_order
        from   workflow_roles
        where  role_id = :role_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::role::get.role_callbacks">
    <querytext>
        select impl.impl_owner_name || '.' || impl.impl_name
        from   acs_sc_impls impl,
               workflow_role_callbacks c
        where  c.role_id = :role_id
        and    impl.impl_id = c.acs_sc_impl_id
        order  by c.sort_order
    </querytext>
  </fullquery>

  <fullquery name="workflow::role::callback_insert.select_sort_order">
    <querytext>
        select coalesce(max(sort_order),0) + 1
        from   workflow_role_callbacks
        where  role_id = :role_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::role::callback_insert.insert_callback">
    <querytext>
        insert into workflow_role_callbacks (role_id, acs_sc_impl_id, sort_order)
        values (:role_id, :acs_sc_impl_id, :sort_order)
    </querytext>
  </fullquery>



</queryset>
