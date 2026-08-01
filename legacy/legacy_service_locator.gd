class_name LegacyServiceLocator
extends RefCounted

static func require(context: Node, service_name: StringName) -> Node:
	var service := context.get_tree().root.get_node_or_null(NodePath(String(service_name)))
	assert(service != null, "Missing isolated legacy service: %s" % service_name)
	return service
