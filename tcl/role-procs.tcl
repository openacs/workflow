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

    # Role info for the workflow is changed, need to flush
    workflow::role::flush_cache -workflow_id $workflow_id

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
    # Get role info from cache
    array set role_data [workflow::role::get_all_info -workflow_id $workflow_id]

    foreach role_id $role_data(role_ids) {
        array set one_role $role_data($role_id)
        
        if { [string equal $one_role(short_name) $short_name] } {
            return $one_role(role_id)
        }
    }
    
    error "workflow::role::get_id role with short_name $short_name not found for workflow $workflow_id"
}

ad_proc -public workflow::role::get_workflow_id {
    {-role_id:required}
} {
    Lookup the workflow_id of a certain role_id.

    @author Peter Marklund
} {
    return [util_memoize \
            [list workflow::role::get_workflow_id_not_cached -role_id $role_id]]
}

ad_proc -private workflow::role::get_workflow_id_not_cached {
    {-role_id:required}
} {
    This is a proc that should only be used internally by the workflow
    API, applications should use workflow::role::get_workflow_id instead.

    @author Peter Marklund
} {
    return [db_string select_workflow_id {}]
}

ad_proc -public workflow::role::get {
    {-role_id:required}
    {-array:required}
} {
    Return information about a role in an array.

    @param role_id The ID of the workflow
    @param array Name of the array you want the info returned in

    @Author Lars Pind (lars@collaboraid.biz)
} {
    set workflow_id [workflow::role::get_workflow_id -role_id $role_id]

    upvar $array row

    # Get info about all roles for this workflow
    array set role_data [workflow::role::get_all_info -workflow_id $workflow_id]

    array set row $role_data($role_id)
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

ad_proc -private workflow::role::get_callbacks {
    {-role_id:required}
    {-contract_name:required}
} {
    Get the impl_names of callbacks of a given contract for a given role.
    
    @param role_id the ID of the role to assign.
    @param contract_name the name of the contract

    @author Lars Pind (lars@collaboraid.biz)
} {
    array set callback_impl_names [get_element -role_id $role_id -element callback_impl_names]

    if { [info exists callback_impl_names($contract_name)] } {
        return $callback_impl_names($contract_name)
    } else {
        return {}
    }
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
    array unset row role_ids
    array unset row callbacks_array
    array unset row callback_ids
    array unset row callback_impl_names

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
    array set roles [list]

    foreach role_id [workflow::get_roles -workflow_id $workflow_id] {
        lappend roles_list [get_element -role_id $role_id -element short_name] [generate_spec -role_id $role_id]
    }

    return $roles_list
}

ad_proc -public workflow::role::callback_insert {
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

    set workflow_id [workflow::role::get_workflow_id -role_id $role_id]
    workflow::role::flush_cache -workflow_id $workflow_id

    return $acs_sc_impl_id
}

ad_proc -private workflow::role::flush_cache {
    {-workflow_id:required}
} {
    Flush all caches related to roles for the given
    workflow. Used internally by the workflow API only.

    @author Peter Marklund
} {
    # TODO: Flush request cache
    # no request cache to flush yet

    # Flush the thread global cache
    util_memoize_flush [list workflow::role::get_all_info_not_cached -workflow_id $workflow_id]    
}

ad_proc -private workflow::role::get_all_info {
    {-workflow_id:required}
} {
    This proc is for internal use in the workflow API only.
    Returns all information related to roles for a certain
    workflow instance. Uses util_memoize to cache values.

    @see workflow::role::get_all_info_not_cached

    @author Peter Marklund
} {
    return [util_memoize [list workflow::role::get_all_info_not_cached \
            -workflow_id $workflow_id] [workflow::cache_timeout]]
}

ad_proc -private workflow::role::get_all_info_not_cached {
    {-workflow_id:required}
} {
    This proc is for internal use in the workflow API only and
    should not be invoked directly from application code. Returns
    all information related to roles for a certain workflow instance.
    Goes to the database on every invocation and should be used together
    with util_memoize.

    @author Peter Marklund
} {
    # For performance we avoid nested queries in this proc
    set role_ids [list]

    db_foreach role_info {} -column_array row {
        set role_id $row(role_id)

        lappend role_ids $role_id

        # store in role,$role_id arrays
        foreach name [array names row] {
            set role,${role_id}($name) $row($name)
        }

        # Cache the mapping role_id -> workflow_id
        util_memoize_seed \
                [list workflow::role::get_workflow_id_not_cached -role_id $role_id] \
                $workflow_id
    }
    
    # Get the callbacks of all roles of the workflow
    foreach role_id $role_ids {
        set role,${role_id}(callbacks) {}
        set role,${role_id}(callback_ids) {}
        array set callback_impl_names,$role_id [list]
        array set callbacks_array,$role_id [list]
    }

    db_foreach role_callbacks {} -column_array row {
        set role_id $row(role_id)

        lappend role,${role_id}(callbacks) "$row(impl_owner_name).$row(impl_name)"
        lappend role,${role_id}(callback_ids) $row(impl_id)

        lappend callback_impl_names,${role_id}(${row(contract_name)}) $row(impl_name)
        set callbacks_array,${role_id}($row(impl_id)) [array get row]
    } 
    unset row

    foreach role_id $role_ids {
        set role,${role_id}(callback_impl_names) [array get callback_impl_names,$role_id]
        set role,${role_id}(callbacks_array) [array get callbacks_array,$role_id]
    }

    # Build up the master role_data array
    foreach role_id $role_ids {
        set role_data($role_id) [array get role,$role_id]
    }

    set role_data(role_ids) $role_ids

    return [array get role_data]
}
