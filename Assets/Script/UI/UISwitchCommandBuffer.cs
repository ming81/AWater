using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class UISwitchCommandBuffer : MonoBehaviour
{
    
    public Button btn;

    private void Awake()
    {
        if (btn == null)
        {
            btn = GetComponent<Button>();
        }
        if (btn != null)
        {
            btn.onClick.AddListener(_SwitchCommandBuffer);
        }
    }

    private void OnDestroy()
    {
        if (btn != null)
        {
            btn.onClick.RemoveListener(_SwitchCommandBuffer);
        }
    }

    private void _SwitchCommandBuffer()
    {
        //CameraRenderTargetReplace.Instance.SetEnable();
        //DepthCommandBuffer.Instance.SetEnable();
    }
}
