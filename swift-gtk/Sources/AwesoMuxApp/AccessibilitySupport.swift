import CGtk
import GLibObject
import Gtk

func setAccessibleLabel<T: Gtk.AccessibleProtocol>(_ accessible: T, _ label: String) {
    var property = GTK_ACCESSIBLE_PROPERTY_LABEL
    let value = GLibObject.Value(label)
    accessible.updatePropertyValue(nProperties: 1, properties: &property, values: value.value_ptr)
}

func setAccessibleDescription<T: Gtk.AccessibleProtocol>(_ accessible: T, _ description: String) {
    var property = GTK_ACCESSIBLE_PROPERTY_DESCRIPTION
    let value = GLibObject.Value(description)
    accessible.updatePropertyValue(nProperties: 1, properties: &property, values: value.value_ptr)
}

func setAccessibleSelected<T: Gtk.AccessibleProtocol>(_ accessible: T, _ selected: Bool) {
    var state = GTK_ACCESSIBLE_STATE_SELECTED
    let value = GLibObject.Value(Int32(selected ? GTK_ACCESSIBLE_TRISTATE_TRUE.rawValue : GTK_ACCESSIBLE_TRISTATE_FALSE.rawValue))
    accessible.updateStateValue(nStates: 1, states: &state, values: value.value_ptr)
}

func setAccessibleExpanded<T: Gtk.AccessibleProtocol>(_ accessible: T, _ expanded: Bool) {
    var state = GTK_ACCESSIBLE_STATE_EXPANDED
    let value = GLibObject.Value(Int32(expanded ? GTK_ACCESSIBLE_TRISTATE_TRUE.rawValue : GTK_ACCESSIBLE_TRISTATE_FALSE.rawValue))
    accessible.updateStateValue(nStates: 1, states: &state, values: value.value_ptr)
}

func announceAccessibilityStatus<T: Gtk.AccessibleProtocol>(
    from accessible: T, _ message: String,
    priority: GtkAccessibleAnnouncementPriority = GTK_ACCESSIBLE_ANNOUNCEMENT_PRIORITY_MEDIUM
) {
    message.withCString { accessible.announce(message: $0, priority: priority) }
}
