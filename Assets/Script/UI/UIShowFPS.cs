using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class UIShowFPS : MonoBehaviour
{
    private float _lastInterval;
    private int _frames = 0;
    private float _fps;

    public Text fpsText;
    public float UpdateInterval = 0.5F;

    // Start is called before the first frame update
    void Start()
    {
        if (fpsText == null)
        {
            fpsText = GetComponent<Text>();
        }

        _lastInterval = Time.realtimeSinceStartup;
        _frames = 0;
    }

    // Update is called once per frame
    void Update()
    {
        ++_frames;

        if (Time.realtimeSinceStartup > _lastInterval + UpdateInterval)
        {
            _fps = _frames / (Time.realtimeSinceStartup - _lastInterval);
            if (fpsText != null)
            {
                fpsText.text = _fps.ToString("0.0");
            }
            _frames = 0;

            _lastInterval = Time.realtimeSinceStartup;
        }
    }
}
