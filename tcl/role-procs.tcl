ad_library {
    Procedures in the workflow::role namespace.
    
    @creation-date 8 January 2003
    @author Lars Pind (lars@collaboraid.biz)
    @author Peter Marklund (peter@collaboraid.biz)
    @cvs-id $Id$
}

namespace eval workflow::role {}




#####
#
#  workflow::role namespace
#
#####

ad_proc -private workflow::role::insert {
    {-workflow_id:required}
    {-short_name:required}
    {-pretty_name:required}
} {
    Inserts the DB row for a new role. You shouldn't normally be usin
    this procedure, use workflow::role::new instead.
    
    @param workflow_id The ID of the workflow the new role belongs to
    @param short_name The short_name of the new role
    @param pretty_name The pretty name of the new role
    @return The ID of the new role
    
    @author Lars Pind (lars@collaboraid.biz)
    @see workflow::role::new
} {        
    db_transaction {
        set role_id [db_nextval "workflow_roles_seq"]
        db_dml do_insert {}
    }
    return $role_id
}

ad_proc -public workflow::role::new {
    {-workflow_id:required}
    {-short_name:required}
    {-pretty_name:required}
    {-callbacks {}}
} {
    Creates a new role for a workflow.
    
    @param workflow_id The ID of the workflow the new role belongs to
    @param short_name The short_name of the new role
    @param pretty_name The pretty name of the new role
    @param callbacks A list of names service-contract implementations.
    @return The ID of the new role
    
    @author Peter Marklund
    @author Lars Pind (lars@collaboraid.biz)
} {        
    db_transaction {
        # Insert the role
        set role_id [insert \
                -workflow_id $workflow_id \
                -short_name $short_name \
                -pretty_name $pretty_name\
                ]

        # Set up the assignment rules
        foreach callback_name $callbacks {
            workflow::role::callback_insert \
                    -role_id $role_id \
                    -name $callback_name
        }
    }
    return $role_id
}

ad_proc -public workflow::role::get_id {
    {-workflow_id:required}
    {-short_name:required}
} {
    Return the role_id of the role with the given short_name in the given workflow.

    @param workflow_id The ID of the workflow
    @param short_name The short_name of the role
    @return role_id of the desired role, or the empty string if it can't be found.
} {
    return [db_string select_role_id {} -default {}]
}

ad_proc -private workflow::role::parse_spec {
    {-workflow_id:required}
    {-short_name:required}
    {-spec:required}
} {
    Parse the spec for an individual role definition.

    @param workflow_id The id of the workflow to delete.
    @param short_name The short_name of the role
    @param spec The roles spec

    @author Lars Pind (lars@collaboraid.biz)
} {
    # Initialize array with default values
    array set role { callbacks {} }
    
    # Get the info from the spec
    array set role $spec

    # Create the role
    set role_id [workflow::role::new \
            -workflow_id $workflow_id \
            -short_name $short_name \
            -pretty_name $role(pretty_name) \
            -callbacks $role(callbacks)
            ]
}

ad_proc -private workflow::role::parse_roles_spec {
    {-workflow_id:required}
    {-spec:required}
} {
    Parse the spec for the block containing the definition of all
    roles for the workflow.

    @param workflow_id The id of the workflow to delete.
    @param spec The roles spec

    @author Lars Pind (lars@collaboraid.biz)
} {
    # roles(short_name) { ... role-spec ... }
    array set roles $spec

    foreach short_name [array names roles] {
        workflow::role::parse_spec \
                -workflow_id $workflow_id \
                -short_name $short_name \
                -spec $roles($short_name)
    }
}

ad_proc -private workflow::role::callback_insert {
    {-role_id:required}
    {-name:required}
    {-sort_order}
} {
    Add an assignment rule to a role.
    
    @param role_id The ID of the role
    @param name Name of service contract implementation, in the form (impl_owner_name).(impl_name), 
    for example, bug-tracker.ComponentMaintainer.
    @param sort_order The sort_order for the rule. Leave blank to add to the end of the list
    
    @author Lars Pind (lars@collaboraid.biz)
} {
    # TODO:
    # Insert for real when the service contracts have been defined
    
    ns_log Error "LARS: workflow::role::callback_insert -- would have inserted the callback $name to role $role_id"
    return

    db_transaction {

        # Get the impl_id
        set acs_sc_impl_id [workflow::service_contract::get_impl_id -name $name]

        # Get the sort order
        if { ![exists_and_not_null sort_order] } {
            set sort_order [db_string select_sort_order {}]
        }

        # Insert the rule
        db_dml insert_rule {}
    }
    return $acs_sc_impl_id
}
