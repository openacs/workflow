<?xml version="1.0"?>
<queryset>
  <rdbms><type>oracle</type><version>8.1.6</version></rdbms>

  <fullquery name="workflow::edit.do_insert">
    <querytext>
        begin
        :1 := workflow.new (
            short_name => :attr_short_name,
            pretty_name => :attr_pretty_name,
            package_key => :attr_package_key,            
            object_id => :attr_object_id,
            object_type => :attr_object_type,
            creation_user => :attr_creation_user,
            creation_ip => :attr_creation_ip,
            context_id => :attr_context_id
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
  
</queryset>
