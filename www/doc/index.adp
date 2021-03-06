
<property name="context">{/doc/workflow {Workflow}} {Workflow Documentation}</property>
<property name="doc(title)">Workflow Documentation</property>
<master>
<h1>Workflow Documentation</h1>

Workflow Documentation
<p>By Lars Pind
</p>
<p>The workflow package provides a service to keep track of a
process involving multiple people around some object. Workflow
keeps track of the process you wish to follow, of where you
currently are in the process (the current state), and who&#39;s
supposed to do what.</p>
<dl>
<dt><a href="mockups">Mockups of alternatives for compound
workflows</a></dt><dt><a href="developer-guide">Package Developer&#39;s Guide to
Workflow</a></dt><dd>This is for developers developing applications that should take
advantage of the workflow service.</dd><dt><a href="specification">Functional Specification</a></dt><dd>This is the document we wrote before implementing workflow
specifying how we intended to implement the package then. It is
inaccurate in a number of places where reality forced us to make
changes.</dd><dt><a href="fall-2003-extensions">Fall 2003
Extensions</a></dt><dd>Adding actions as sub-workflows, automatic/timed actions, more
conditions before actions are enabled, dynamic outcome of actions,
resolution codes.</dd>
</dl>
<h2>Version History</h2>
<ul>
<li>
<strong>1.0d4</strong> Resolved conflicts with old acs-workflow
package, so they install side by side. (May 11, 2003)</li><li>
<strong>1.0d3</strong> Added Tcl API workflow::case::delete ;
fixed bug in PL/SQL implementation of
workflow_case.delete/workflow_case__delete ; added \@see to
workflow::case::insert.</li><li>
<strong>1.0d2</strong> Completed package developer&#39;s guide.
Added -action_id switch to workflow::case::get_activity_html.</li><li>
<strong>1.0d1</strong> Bumped up the version number to 1.0 to
reflect the fact that this package is actually at a steady state
and fully useful as is. Also added a little API and cleaned up
things a bit, the kind of things you learn while writing the
documentation.</li><li>
<strong>0.2d2</strong> First version released along with
OpenACS 4.6.2.</li>
</ul>
<h2>Todo</h2>
<ul>
<li>Internationalization.</li><li>Add API for modifying live workflows, including ensuring that
the modifications are always safe (i.e. you can&#39;t delete a
state that&#39;s used.)</li><li>Add a user interface for defining workflows.</li><li>Add a user interface for monitoring workflows and bulk changing
the state of workflows.</li><li>Periodically notify people of their outstanding assigned
actions.</li><li>Add a task list user interface, either as part of the Workflow
package, or as a separate package.</li><li>Add support for petri nets and other models.</li><li>Add timing of actions, deadlines, and integrate those with
calendar.</li><li>Application integration with certain states and actions. For
example, in bug-tracker, we treat the "Open" and
"Closed" states specially. We also treat the
"Resolve" action specially. Should be possible to define
this link.</li><li>Add workflow variants, so you can ship your application with
multiple default implementations of the same workflow and let the
user choose between the available variants (e.g. simple approval
vs. multiple approval variants, choice of triage and Q&amp;A steps
in the bug-tracker, etc.). This should probably be tied to some
concept of an 'application' as in the bullet above.</li>
</ul>
<hr>
<a href="mailto:lars\@pinds.com"></a>
<address>lars\@pinds.com</address>
