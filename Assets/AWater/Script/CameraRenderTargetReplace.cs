using UnityEngine;
using UnityEngine.Rendering;
using System.Collections.Generic;

namespace AWater
{
    [ExecuteInEditMode] // Make water live-update even when not in play mode
    public class CameraRenderTargetReplace : MonoBehaviour
    {
        public Camera m_Camera;
        public bool m_DisablePostRender = false;


        private int m_ScreenWidth = 0;
        private int m_ScreenHeight = 0;

        [HideInInspector]
        public RenderTexture DepthRenderTexture
        {
            get
            {
                return m_DepthRenderTexture;
            }
        }

        public RenderTexture ColorRenderTexture
        {
            get
            {
                return m_ColorRenderTexture;
            }
        }

        private RenderTexture m_ColorRenderTexture;
        private RenderTexture m_DepthRenderTexture;
        private bool _enableTargetBuffers = true;
        private bool _isExisting = false;

        public void EnableTargetBuffers(bool enable)
        {
            if (enable != _enableTargetBuffers)
            {
                _enableTargetBuffers = enable;
                if (enable)
                {
                    if (m_ColorRenderTexture != null && m_DepthRenderTexture != null && m_Camera != null)
                    {
                        m_Camera.SetTargetBuffers(m_ColorRenderTexture.colorBuffer, m_DepthRenderTexture.depthBuffer);
                    }
                    else
                    {
                        UpdateRenderTargets();
                    }
                }
                else
                {
                    m_Camera.targetTexture = null;
                }
            }
        }

        private void OnEnable()
        {
            if (!m_Camera)
            {
                return;
            }
            if (!Application.isPlaying)
            {
                EnableTargetBuffers(false);
                m_Camera.depthTextureMode = DepthTextureMode.Depth;
                Shader.DisableKeyword("USE_COPY_DEPTH_TEXTURE");
            }
            else
            {
                EnableTargetBuffers(true);
                m_Camera.depthTextureMode = DepthTextureMode.None;
                Shader.EnableKeyword("USE_COPY_DEPTH_TEXTURE");
            }

            UpdateRenderTargets();
        }

        //在退出play模式时释放资源有概率引起编辑器崩溃.
        private void OnApplicationQuit()
        {
            _isExisting = true;
        }

        private void OnDestroy()
        {
            if (!_isExisting)
            {
                _ClearRenderTexture();
            }
        }

        private void _ClearRenderTexture()
        {
            if (m_ColorRenderTexture != null)
            {
                DestroyImmediate(m_ColorRenderTexture);
                m_ColorRenderTexture = null;
            }
            if (m_DepthRenderTexture != null)
            {
                DestroyImmediate(m_DepthRenderTexture);
                m_DepthRenderTexture = null;
            }
        }

        private void Update()
        {
            UpdateRenderTargets();
        }

        private void OnPostRender()
        {
            if (_enableTargetBuffers && !m_DisablePostRender)
            {
                Graphics.Blit(m_ColorRenderTexture, (RenderTexture)null);
            }
        }

        private void UpdateRenderTargets()
        {
            if (!_enableTargetBuffers || !m_Camera)
                return;

            int width = Screen.width ;
            int height = Screen.height;

            if(m_ScreenWidth != width || m_ScreenHeight != height || m_ColorRenderTexture == null || m_DepthRenderTexture == null)
            {
                m_ScreenWidth = width;
                m_ScreenHeight = height;
                _ClearRenderTexture();

                m_ColorRenderTexture = new RenderTexture(width , height, 0, m_Camera.allowHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default);
                m_DepthRenderTexture = new RenderTexture(width, height, 32, RenderTextureFormat.Depth);

                if (!m_ColorRenderTexture.Create() || !m_DepthRenderTexture.Create())
                {
                    _ClearRenderTexture();
                    Debug.LogError("failed to create rendertexture");
                }
                else
                {
                    m_Camera.SetTargetBuffers(m_ColorRenderTexture.colorBuffer, m_DepthRenderTexture.depthBuffer);
                }
            }
        }
    }

}
