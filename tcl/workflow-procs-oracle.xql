<?xml version="1.0"?>
<queryset>
  <rdbms><type>oracle</type><version>8.1.6</version></rdbms>

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
            :1 := workflow.delete(:workflow_id);
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
