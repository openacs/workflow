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
    {-sort_order {}}
} {
    Inserts the DB row for a new role. You shouldn't normally be usin
    this procedure, use workflow::role::new instead.
    
    @param workflow_id The ID of the workflow the new role belongs to
    @param short_name The short_name of the new role
    @param pretty_name The pretty name of the new role
    @param sort_order             The number which this role should be in the sort ordering sequence. 
                                  Leave blank to add role at the end. If you provide a sort_order number
                                  which already exists, existing roles are pushed down one number.
    @return The ID of the new role
    
    @author Lars Pind (lars@collaboraid.biz)
    @see workflow::role::new
} {        
    db_transaction {

        if { [empty_string_p $sort_order] } {
            set sort_order [workflow::default_sort_order \
                    -workflow_id $workflow_id \
                    -table_name "workflow_roles"]
        } else {
            set sort_order_taken_p [db_string select_sort_order_p {}]
            if { $sort_order_taken_p } {
                db_dml update_sort_order {}
            }
        }

        set role_id [db_nextval "workflow_roles_seq"]

        db_dml do_insert {}
    }
    return $role_id
}

ad_proc -public workflow::role::new {
    {-workflow_id:required}
    {-short_name:required}
    {-pretty_name:required}
    {-sort_order {}}
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
                -pretty_name $pretty_name \
                -sort_order $sort_order \
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

    @author Lars Pind (lars@collaboraid.biz)
} {
    return [db_string select_role_id {} -default {}]
}

ad_proc -public workflow::role::get {
    {-role_id:required}
    {-array:required}
} {
    Return information about a role in an array.

    @param role_id The ID of the workflow
    @param array Name of the array you want the info returned in

    @author Lars Pind (lars@collaboraid.biz)
} {
    upvar $array row

    db_1row role_info {} -column_array row

    set row(callbacks) [db_list role_callbacks {}]
}

ad_proc -public workflow::role::get_element {
    {-role_id:required}
    {-element:required}
} {
    Return a single element from the information about a role.

    @param role_id The ID of the workflow
    @return element The element you asked for

    @author Lars Pind (lars@collaboraid.biz)
} {
    get -role_id $role_id -array row
    return $row($element)
}

ad_proc -private workflow::role::parse_spec {
    {-workflow_id:required}
    {-short_name:required}
    {-spec:required}
} {
    Parse the spec for an individual role definition.

    @param workflow_id The id of the workflow the role should be added to.
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
    foreach { short_name spec } $spec {
        workflow::role::parse_spec \
                -workflow_id $workflow_id \
                -short_name $short_name \
                -spec $spec
    }
}

ad_proc -private workflow::role::generate_spec {
    {-role_id:required}
} {
    Generate the spec for an individual role definition.

    @param role_id The id of the role to generate spec for.
    @return spec The roles spec

    @author Lars Pind (lars@collaboraid.biz)
} {
    get -role_id $role_id -array row

    # Get rid of elements that shouldn't go into the spec
    array unset row short_name 
    array unset row role_id
    array unset row workflow_id
    array unset row sort_order
    
    # Get rid of empty strings
    foreach name [array names row] {
        if { [empty_string_p $row($name)] } {
            array unset row $name
        }
    }
    
    set spec {}
    foreach name [lsort [array names row]] {
        lappend spec $name $row($name)
    }

    return $spec
}

ad_proc -private workflow::role::generate_roles_spec {
    {-workflow_id:required}
} {
    Generate the spec for the block containing the definition of all
    roles for the workflow.

    @param workflow_id The id of the workflow to delete.
    @return The roles spec

    @author Lars Pind (lars@collaboraid.biz)
} {
    # roles(short_name) { ... role-spec ... }
    set roles [list]

    foreach role_id [workflow::get_roles -workflow_id $workflow_id] {
        lappend roles [get_element -role_id $role_id -element short_name] [generate_spec -role_id $role_id]
    }
    
    return $roles
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
    db_transaction {

        # Get the impl_id
        set acs_sc_impl_id [workflow::service_contract::get_impl_id -name $name]

        # Get the sort order
        if { ![exists_and_not_null sort_order] } {
            set sort_order [db_string select_sort_order {}]
        }

        # Insert the rule
        db_dml insert_callback {}
    }

    return $acs_sc_impl_id
}
