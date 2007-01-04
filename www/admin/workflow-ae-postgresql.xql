<?xml version="1.0"?>
 <queryset>
   <rdbms><type>postgresql</type><version>7.2</version></rdbms>
         <fullquery name="get_packages">
                 <querytext>
 	                 select  n.name,
 	                         n.object_id,
 	                         n.name as rawname,
 	                         tree_level(n2.tree_sortkey) as level
 	                 from    site_nodes n, site_nodes n2
 	                 where   n.name is not null
 	                 and     n.tree_sortkey between n2.tree_sortkey and tree_right(n2.tree_sortkey)
 	                 and     n.object_id=405
                 </querytext>
         </fullquery>
 </queryset>
