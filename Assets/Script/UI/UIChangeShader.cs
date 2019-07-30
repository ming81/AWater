using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class UIChangeShader : MonoBehaviour
{
    public Shader[] shaders;
    public Renderer renderer;
    public Button btn;
    private int _curShaderIndex;

    private void Awake()
    {
        if (btn == null)
        {
            btn = GetComponent<Button>();
        }
        if (btn != null)
        {
            btn.onClick.AddListener(_ChangeShader);
        }
    }

    private void OnDestroy()
    {
        if (btn != null)
        {
            btn.onClick.RemoveListener(_ChangeShader);
        }
    }

    // Start is called before the first frame update
    void Start()
    {
        if (renderer == null)
        {
            renderer = GetComponent<Renderer>();
        }
        if (renderer != null && shaders.Length > 0)
        {
            renderer.sharedMaterial.shader = shaders[0];
        }
        _curShaderIndex = 0;
    }

    private void _ChangeShader()
    {
        if (renderer != null && shaders.Length > 0)
        {
            _curShaderIndex = (_curShaderIndex + 1) % shaders.Length;           
            renderer.sharedMaterial.shader = shaders[_curShaderIndex];
        }
    }

}
