ad_library {
  Register acs-automated-testing test cases for the workflow
  package on server startup.

  @author Peter Marklund
  @creation-date 10 January 2003
  @cvs-id $Id$
}

#####
#
# Register the test cases
#
#####

aa_register_case bugtracker_workflow_create_normal {
    Test creation and teardown of an FSM workflow case.

    @author Peter Marklund
    @creation-date 16 January 2003
} {
    workflow::test::run_bug_tracker_test -create_proc "workflow::test::workflow_setup"
}

aa_register_case bugtracker_workflow_create_array_style {
    Test creation and teardown of an FSM workflow case, with array style specification.

    @author Lars Pind
    @creation-date 21 January 2003
} {
    workflow::test::run_bug_tracker_test -create_proc "workflow::test::workflow_setup_array_style"
}

aa_register_case bugtracker_workflow_clone {
    Test creation and teardown of cloning an FSM workflow case.

    @author Lars Pind
    @creation-date 22 January 2003
} {
    set workflow_id_list [list]
    set test_chunk {
        set workflow_id_1 [workflow::test::workflow_setup]
        lappend workflow_id_list $workflow_id_1
        set workflow_id_2 [workflow::fsm::clone -workflow_id $workflow_id_1 -object_id [workflow::test::workflow_object_id_2]]
        lappend workflow_id_list $workflow_id_2

        set spec_1 [workflow::fsm::generate_spec -workflow_id $workflow_id_1]
        set spec_2 [workflow::fsm::generate_spec -workflow_id $workflow_id_2]

        aa_true "Generated spec from original and cloned workflow should be identical" \
                [string equal $spec_1 $spec_2]
    } 

    set error_p [catch $test_chunk errMsg]

    # Teardown
    foreach workflow_id $workflow_id_list {
        workflow::delete -workflow_id $workflow_id
    }

    if { $error_p } {    
        global errorInfo
        aa_false "error during setup: $errMsg - $errorInfo" $error_p
    }
}

aa_register_case workflow_spec_with_message_keys {
    Test creating a workflow from a spec with message catalog
    keys in it and then generating a spec from that workflow
    and making sure that the spec is preserved (message keys are not
    localized)

    @author Peter Marklund
} {
    set test_chunk {

        set workflow_id [workflow::fsm::new_from_spec \
            -spec [workflow::test::get_message_key_spec]]

        set generated_spec [workflow::fsm::generate_spec -workflow_id $workflow_id]
        
        aa_true "Checking that generated spec 2 is identical to the spec that we created from (except for ordering)" \
            [array_lists_equal_p $generated_spec [workflow::test::get_message_key_spec]]
    }

    set teardown_chunk {
        set workflow_id [workflow::get_id -package_key acs-automated-testing -short_name test_message_keys]
        workflow::delete -workflow_id $workflow_id
    }
    
    workflow::test::run_with_teardown $test_chunk $teardown_chunk
}

