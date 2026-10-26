import "../../qml/Components"
import QtQuick
import QtTest

Item {
    id: root

    // Stand-in for the C++ context property the component expects
    property var theme: ({
            "text": "#ffffff",
            "textSecondary": "#cccccc"
        })

    width: 400
    height: 200

    SwitchRow {
        id: sw
        checked: true
    }

    TestCase {
        name: "SwitchRowBinding"
        when: windowShown

        // Contract: the switch must follow host updates to checked even after
        // user toggles (e.g. OptionsDialog.loadOptions). The old write-back to
        // checked also destroyed caller-supplied bindings.
        function test_external_updates_reach_switch_after_user_toggle() {
            var inner = findChild(sw, "innerSwitch");
            compare(inner.checked, true);

            mouseClick(inner, inner.width / 2, inner.height / 2);
            compare(sw.checked, false);
            compare(inner.checked, false);

            // imperative update from the host, like loadOptions()
            sw.checked = true;
            compare(inner.checked, true);

            mouseClick(inner, inner.width / 2, inner.height / 2);
            compare(sw.checked, false);
            compare(inner.checked, false);
        }
    }
}
