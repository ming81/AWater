using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class UISwitchGoActive : MonoBehaviour
{
    public GameObject go;
    public Button btn;


    private void Awake()
    {
        if (btn == null)
        {
            btn = GetComponent<Button>();
        }
        if(btn != null)
        {
            btn.onClick.AddListener(_Switch);
        }
    }

    private void OnDestroy()
    {
        if (btn != null)
        {
            btn.onClick.RemoveListener(_Switch);
        }
    }

    private void _Switch()
    {
        if (go != null)
        {
            var renderer = go.GetComponent<Renderer>();
            if (renderer != null)
            {
                renderer.enabled = !renderer.enabled;
            }
            else
            {
                go.SetActive(!go.activeSelf);
            }
        }
    }
}
