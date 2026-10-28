import "../../Components"
import "../../Utils/Constants.js" as Constants
import "../../Utils/DataUtils.js" as DataUtils
import QtQuick 2.15
import QtQuick.Controls 2.15

SectionBase {
    id: root

    function _flipModeFromBools(hflip, vflip) {
        if (hflip && vflip)
            return "both";
        if (hflip)
            return "horizontal";
        if (vflip)
            return "vertical";
        return "none";
    }

    function getFiltersData() {
        var vf = {};
        var di = deinterlaceCombo.currentIndex;
        if (di > 0)
            vf.deinterlace = Constants.deinterlaceOptions[di];
        var dn = denoiseCombo.currentIndex;
        if (dn > 0)
            vf.denoise = Constants.denoiseOptions[dn];

        vf.crop_top = _cropValue(cropTopField.text);
        vf.crop_right = _cropValue(cropRightField.text);
        vf.crop_bottom = _cropValue(cropBottomField.text);
        vf.crop_left = _cropValue(cropLeftField.text);

        var rot = parseInt(Constants.rotateOptions[rotateCombo.currentIndex]);
        if (rot > 0)
            vf.rotate = rot;

        var flip = Constants.flipKeys[flipCombo.currentIndex];
        if (flip === "horizontal" || flip === "both")
            vf.hflip = true;
        if (flip === "vertical" || flip === "both")
            vf.vflip = true;

        return { "video_filters": Object.keys(vf).length > 0 ? vf : null };
    }

    function setFiltersData(d) {
        var vf = d.video_filters || {};
        DataUtils.setIndex(Constants.deinterlaceOptions, deinterlaceCombo, vf.deinterlace || "none");
        DataUtils.setIndex(Constants.denoiseOptions, denoiseCombo, vf.denoise || "none");
        cropTopField.text = vf.crop_top != null ? String(vf.crop_top) : "";
        cropRightField.text = vf.crop_right != null ? String(vf.crop_right) : "";
        cropBottomField.text = vf.crop_bottom != null ? String(vf.crop_bottom) : "";
        cropLeftField.text = vf.crop_left != null ? String(vf.crop_left) : "";
        DataUtils.setIndex(Constants.rotateOptions, rotateCombo, String(vf.rotate || "0"));
        DataUtils.setIndex(Constants.flipKeys, flipCombo, _flipModeFromBools(!!vf.hflip, !!vf.vflip));
    }

    function _cropValue(text) {
        var v = parseInt(text);
        return isNaN(v) || v <= 0 ? null : v;
    }

    SectionHeader {
        text: qsTr("Filters")
    }

    LabeledRow {
        id: deinterlaceRow

        label: qsTr("Deinterlace")

        ComboBox {
            id: deinterlaceCombo

            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            model: Constants.deinterlaceOptions
            currentIndex: 0
            onCurrentIndexChanged: root.emitChanged();
        }
    }

    LabeledRow {
        label: qsTr("Denoise")

        ComboBox {
            id: denoiseCombo

            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            model: Constants.denoiseOptions
            currentIndex: 0
            onCurrentIndexChanged: root.emitChanged();
        }
    }

    readonly property int cropSideLabelWidth: 64

    Row {
        spacing: 8
        width: parent.width

        Label {
            id: cropLabel

            text: qsTr("Crop")
            color: theme.textSecondary
            width: deinterlaceRow.effectiveLabelWidth
            verticalAlignment: Text.AlignVCenter
        }

        Column {
            spacing: 8
            width: parent.width - cropLabel.width - parent.spacing

            Row {
                id: cropTopBottomRow

                readonly property int fieldWidth: (width - 2 * cropSideLabelWidth - 3 * spacing) / 2

                spacing: 4
                width: parent.width

                Label {
                    text: qsTr("Top")
                    color: theme.textSecondary
                    width: cropSideLabelWidth
                    verticalAlignment: Text.AlignVCenter
                }

                TextField {
                    id: cropTopField

                    width: cropTopBottomRow.fieldWidth
                    placeholderText: "0"
                    onTextChanged: root.emitChanged();

                    validator: IntValidator {
                        bottom: 0
                        top: 10000
                    }
                }

                Label {
                    text: qsTr("Bottom")
                    color: theme.textSecondary
                    width: cropSideLabelWidth
                    verticalAlignment: Text.AlignVCenter
                }

                TextField {
                    id: cropBottomField

                    width: cropTopBottomRow.fieldWidth
                    placeholderText: "0"
                    onTextChanged: root.emitChanged();

                    validator: IntValidator {
                        bottom: 0
                        top: 10000
                    }
                }
            }

            Row {
                id: cropLeftRightRow

                readonly property int fieldWidth: (width - 2 * cropSideLabelWidth - 3 * spacing) / 2

                spacing: 4
                width: parent.width

                Label {
                    text: qsTr("Left")
                    color: theme.textSecondary
                    width: cropSideLabelWidth
                    verticalAlignment: Text.AlignVCenter
                }

                TextField {
                    id: cropLeftField

                    width: cropLeftRightRow.fieldWidth
                    placeholderText: "0"
                    onTextChanged: root.emitChanged();

                    validator: IntValidator {
                        bottom: 0
                        top: 10000
                    }
                }

                Label {
                    text: qsTr("Right")
                    color: theme.textSecondary
                    width: cropSideLabelWidth
                    verticalAlignment: Text.AlignVCenter
                }

                TextField {
                    id: cropRightField

                    width: cropLeftRightRow.fieldWidth
                    placeholderText: "0"
                    onTextChanged: root.emitChanged();

                    validator: IntValidator {
                        bottom: 0
                        top: 10000
                    }
                }
            }
        }
    }

    LabeledRow {
        label: qsTr("Rotate")

        ComboBox {
            id: rotateCombo

            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            model: Constants.rotateOptions
            currentIndex: 0
            onCurrentIndexChanged: root.emitChanged();
        }
    }

    LabeledRow {
        label: qsTr("Flip")

        ComboBox {
            id: flipCombo

            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            model: Constants.flipLabels
            currentIndex: 0
            onCurrentIndexChanged: root.emitChanged();
        }
    }
}
