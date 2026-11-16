/*
    Hard Edge Selector v1.0.2 for 3ds Max 2026
    Default: smoothing-group boundaries enabled; angle check disabled.
*/
try (destroyDialog HardEdgeSelectorUI) catch()
global HardEdgeSelectorUI
global HES_VERSION = "1.0.2"

fn hesAngleBetween n1 n2 =
(
    local d = dot (normalize n1) (normalize n2)
    d = amax -1.0 (amin 1.0 d)
    acos d
)

fn hesCollectEdges obj angleDeg useAngle useSG useID =
(
    local edgeCount = polyop.getNumEdges obj
    local faceCount = polyop.getNumFaces obj
    local faceNormals = #()
    local faceSG = #()
    local faceIDs = #()
    for f = 1 to faceCount do
    (
        append faceNormals (if useAngle then (polyop.getFaceNormal obj f) else [0,0,1])
        append faceSG (if useSG then (polyop.getFaceSmoothGroup obj f) else 0)
        append faceIDs (if useID then (polyop.getFaceMatID obj f) else 0)
    )
    local result = #{ }
    for e = 1 to edgeCount do
    (
        local fs = polyop.getEdgeFaces obj e
        local hard = (fs.count == 1)
        if fs.count >= 2 do
        (
            local f1 = fs[1]
            local f2 = fs[2]
            if useAngle and (hesAngleBetween faceNormals[f1] faceNormals[f2] >= angleDeg) do hard = true
            if useSG and ((bit.and faceSG[f1] faceSG[f2]) == 0) do hard = true
            if useID and (faceIDs[f1] != faceIDs[f2]) do hard = true
        )
        if hard do result[e] = true
    )
    result
)

rollout HardEdgeSelectorUI "Hard Edge Selector v1.0.2" width:360
(
    label verLabel "Version 1.0.2 | 3ds Max 2026" align:#right
    checkbox sgCheck "スムージンググループ境界" checked:true
    checkbox angleCheck "角度で判定" checked:false
    spinner angleSpinner "しきい値" range:[0,180,30] type:#float scale:1
    checkbox idCheck "マテリアルID境界" checked:false
    button runButton "ハードエッジを選択" width:330 height:32
    editText logBox "実行ログ:" height:150 readonly:true text:"待機中"

    on runButton pressed do
    (
        if selection.count == 0 then
            logBox.text = "エラー: オブジェクトを選択してください。"
        else if not (angleCheck.checked or sgCheck.checked or idCheck.checked) then
            logBox.text = "エラー: 判定条件を1つ以上選択してください。"
        else
        (
            local targets = for n in selection where superclassof n == GeometryClass collect n
            local successes = 0
            local totalEdges = 0
            logBox.text = ("開始: " + (targets.count as string) + " オブジェクト")
            undo "Select Hard Edges v1.0.2" on
            (
                for obj in targets do
                (
                    try
                    (
                        local selectedEdges = hesCollectEdges obj angleSpinner.value angleCheck.checked sgCheck.checked idCheck.checked
                        local ep = Edit_Poly()
                        addModifier obj ep
                        max modify mode
                        select obj
                        modPanel.setCurrentObject ep
                        ep.SetEPolySelLevel #Edge
                        subObjectLevel = 2
                        ep.SetSelection #Edge selectedEdges node:obj
                        ep.Select #Edge selectedEdges node:obj
                        local actual = ep.GetSelection #Edge node:obj
                        totalEdges += actual.numberSet
                        successes += 1
                        logBox.text += ("\r\n成功: " + obj.name + " — " + (actual.numberSet as string) + " 辺選択")
                    )
                    catch
                    (
                        logBox.text += ("\r\n失敗: " + obj.name + " — " + (getCurrentException() as string))
                    )
                )
            )
            max modify mode
            redrawViews()
            logBox.text += ("\r\n完了: 成功 " + (successes as string) + " / " + (totalEdges as string) + " エッジ")
        )
    )
)
createDialog HardEdgeSelectorUI style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
