using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode] // Make water live-update even when not in play mode
public class ShowFPSScript : MonoBehaviour {

    //更新的时间间隔
    public float UpdateInterval = 0.5F;
    //最后的时间间隔
    private float _lastInterval;
    //帧[中间变量 辅助]
    private int _frames = 0;
    //当前的帧率
    private float _fps;

    // Use this for initialization
    void Start () {
        //Application.targetFrameRate=60;

        _lastInterval = Time.realtimeSinceStartup;

        _frames = 0;
    }

    // Update is called once per frame
    void Update () {
        ++_frames;

        if (Time.realtimeSinceStartup > _lastInterval + UpdateInterval)
        {
            _fps = _frames / (Time.realtimeSinceStartup - _lastInterval);

            _frames = 0;

            _lastInterval = Time.realtimeSinceStartup;
        }
    }

    void OnGUI()
    {
        GUI.Label(new Rect(100, 100, 200, 200), "FPS:" + _fps.ToString("f2"));
    }
}
