import CGtk
import GLibObject
import Gtk

private func makeAccessibleObject(type: GType, role: GtkAccessibleRole) -> GLibObject.ObjectRef {
    let roleValue = GLibObject.Value()
    _ = roleValue.init_(gType: gtk_accessible_role_get_type())
    roleValue.setEnum(vEnum: Int(role.rawValue))
    return "accessible-role".withCString { propertyName in
        var name: UnsafePointer<CChar>? = propertyName
        return GLibObject.ObjectRef(
            properties: type, nProperties: 1, names: &name, values: roleValue.value_ptr
        )
    }
}

func makeAccessibleButton(role: GtkAccessibleRole) -> ButtonRef {
    ButtonRef(raw: makeAccessibleObject(type: gtk_button_get_type(), role: role).ptr)
}

func makeAccessibleToggleButton(role: GtkAccessibleRole) -> ToggleButtonRef {
    ToggleButtonRef(raw: makeAccessibleObject(type: gtk_toggle_button_get_type(), role: role).ptr)
}

func makeAccessibleLabel(_ text: String, role: GtkAccessibleRole) -> LabelRef {
    let label = LabelRef(raw: makeAccessibleObject(type: gtk_label_get_type(), role: role).ptr)
    label.label = text
    return label
}

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

func setAccessibleSetPosition<T: Gtk.AccessibleProtocol>(
    _ accessible: T, position: Int, count: Int
) {
    guard position > 0, count > 0, position <= count else { return }
    var positionRelation = GTK_ACCESSIBLE_RELATION_POS_IN_SET
    let positionValue = GLibObject.Value(Int32(position))
    accessible.updateRelationValue(
        nRelations: 1, relations: &positionRelation, values: positionValue.value_ptr
    )
    var countRelation = GTK_ACCESSIBLE_RELATION_SET_SIZE
    let countValue = GLibObject.Value(Int32(count))
    accessible.updateRelationValue(
        nRelations: 1, relations: &countRelation, values: countValue.value_ptr
    )
}

func setAccessibleHasPopup<T: Gtk.AccessibleProtocol>(_ accessible: T) {
    var popupProperty = GTK_ACCESSIBLE_PROPERTY_HAS_POPUP
    let popupValue = GLibObject.Value(true)
    accessible.updatePropertyValue(
        nProperties: 1, properties: &popupProperty, values: popupValue.value_ptr
    )
}

func setAccessibleLevel<T: Gtk.AccessibleProtocol>(_ accessible: T, _ level: Int) {
    guard level > 0 else { return }
    var property = GTK_ACCESSIBLE_PROPERTY_LEVEL
    let value = GLibObject.Value(Int32(level))
    accessible.updatePropertyValue(
        nProperties: 1, properties: &property, values: value.value_ptr
    )
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

func setAccessibleHidden<T: Gtk.AccessibleProtocol>(_ accessible: T, _ hidden: Bool) {
    var state = GTK_ACCESSIBLE_STATE_HIDDEN
    let value = GLibObject.Value(hidden)
    accessible.updateStateValue(nStates: 1, states: &state, values: value.value_ptr)
}

/// Installs visible button text without letting GTK derive the parent button's
/// accessible name from that decorative child. Call `setAccessibleLabel` on
/// the button with the real action name after installing the text.
func setDecorativeButtonText(_ button: ButtonRef, _ text: String) {
    let label = LabelRef(str: text)
    setAccessibleHidden(label, true)
    button.set(child: label)
}

func announceAccessibilityStatus<T: Gtk.AccessibleProtocol>(
    from accessible: T, _ message: String,
    priority: GtkAccessibleAnnouncementPriority = GTK_ACCESSIBLE_ANNOUNCEMENT_PRIORITY_MEDIUM
) {
    message.withCString { accessible.announce(message: $0, priority: priority) }
}
