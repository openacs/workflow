
    # Array-list with list of lists style

    set operations {
        GetObjectType {
            {operation_desc "Get the object type for which this operation is valid."}
            {inputspec {}}
            {outputspec {object_type:string}}
            {nargs 0}
            {iscachable_p "t"}
        }
        GetPrettyName {
            {operation_desc "Get the pretty name. May contain #...#, so should be localized."}
            {inputspec {}}
            {outputspec {pretty_name:string}}
            {nargs 0}
            {iscachable_p "t"}
        }
        GetAssignees {
            {operation_desc "Get the assignees as a Tcl list of party_ids, of the default assignees for this case, object, role"}
            {inputspec {case_id:integer,object_id:integer,role_id:integer}}
            {outputspec {party_ids:[integer]}}
            {nargs 3}
            {iscachable_p "f"}
        }
    }
    


#####
#
# Style one: Lists of lists of lists with potentially unclear semantics
#
#####

ad_proc -private workflow::install::create_service_contracts {} {

    # Array-list style
    
acs_sc::contract::new \
        -contract_name [workflow::service_contract::role_default_assignee] \
        -contract_desc "Service contract to get the default assignees for a role from parameters case_id, object_id and role_id" \
        -operations {

    GetObjectType {
        operation_desc "Get the object type for which this operation is valid."
        inputspec {}
        outputspec {object_type:string}
        nargs 0
        iscachable_p "t"
    }

    GetPrettyName {
        operation_desc "Get the pretty name. May contain #...#, so should be localized."
        inputspec {}
        outputspec {pretty_name:string}
        nargs 0
        iscachable_p "t"
    }

    GetAssignees {
        operation_desc "Get the assignees as a Tcl list of party_ids, of the default assignees for this case, object, role"
        inputspec {case_id:integer,object_id:integer,role_id:integer}
        outputspec {party_ids:[integer]}
        nargs 3
        iscachable_p "f"
    }
}

}

#####
#
# Style two: Using procs in procs with global variables
#
#####

ad_proc -private workflow::install::create_service_contracts {} {

acs_sc::contract::new \
        -contract_name [workflow::service_contract::role_default_assignee] \
        -contract_desc "Service contract to get the default assignees for a role from parameters case_id, object_id and role_id" \
        -operations {

    operation \
            -operation_name GetObjectType \
            -operation_desc "Get the object type for which this operation is valid." \
            -inputspec {} \
            -outputspec {object_type:string} \
            -nargs 0 \
            -iscachable_p "t"

    operation \
            -operation_name GetPrettyName \
            -operation_desc "Get the pretty name. May contain #...#, so should be localized." \
            -inputspec {} \
            -outputspec {pretty_name:string} \
            -nargs 0 \
            -iscachable_p "t"

    operation \
            -operation_name GetAssignees \
            -operation_desc "Get the assignees as a Tcl list of party_ids, of the default assignees for this case, object, role" \
            -inputspec {case_id:integer,object_id:integer,role_id:integer} \
            -outputspec {party_ids:[integer]} \
            -nargs 3 \
            -iscachable_p "f"
}

}

#
# Corresponding Service Contract Definition API
#

ad_proc -public acs_sc::contract::new {
    {-contract_name:required}
    {-contract_dec {}}
    {-oprations}
} {
    insert -contract_name $contract_name -contract_desc $contract_desc

    if { [exists_and_not_null operations] } {

        namespace eval ::acs_sc::contract::define variable contract_name $contract_name

        namespace eval ::acs_sc::contract::define $operations
    }
}

ad_proc -public acs_sc::contract::define::operation {
    {-operation_name:required}
    {-operation_desc {}}
    {-inputspec {}}
    {-outputspec {}}
    {-nargs 0}
    {-iscachable_p "f"}
} {
    variable contract_name

    set inputtype "${contract_name}.${operatoin_name}.InputType"

    acs_sc::msg_type::insert \
            -msg_type_name $inputtype \
            -msg_type_spec $inputspec
            
    set outputtype "${contract_name}.${operation_name}.OutputType"

    acs_sc::msg_type::insert \
            -msg_type_name $outputtype \
            -msg_type_spec $outputspec
    
    acs_sc::operation::insert \
            -contract_name $contract_name \
            -operation_desc $operation_desc \
            -inputtype $inputtype \
            -outputtype $outputtype \
            -nargs $nargs \
            -iscachable_p $iscachable_p
}




#############################################################


proc create_service_contracts {} {
    acs_sc::contract::new DefaultAssignees {
        operation GetObjectType
        operation GetPrettyName
        operation GetAssignees
    }
    acs_sc::contract::new SideEffect {
        operation GetObjectType
        operation GetPrettyName
        operation DoSideEffect
    }
}

namespace eval acs_sc::contract {}
namespace eval acs_sc::contract::define {}

proc acs_sc::contract::new { contract_name {operations {}} } {
    puts "New Contract: $contract_name"
    if { ![string equal $operations ""] } {
        puts "Operations:"
        namespace eval ::acs_sc::contract::define variable contract_name $contract_name
        namespace eval ::acs_sc::contract::define $operations
    }
}

proc acs_sc::contract::define::operation { operation_name } {
    variable contract_name
    puts "Operation: ${contract_name}.${operation_name}"
}

create_service_contracts

