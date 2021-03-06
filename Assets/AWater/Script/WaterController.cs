using System;
using UnityEngine;
using UnityEngine.Rendering;
using System.Collections.Generic;

namespace AWater
{
    [ExecuteInEditMode] // Make water live-update even when not in play mode
    public class WaterController : MonoBehaviour
    {
        public enum EReflectMode
        {
            ReflM_Cube,
            ReflM_SSR,
            ReflM_Planer
        };

        public enum ERefractMode
        {
            RefrM_Simple,
            RefrM_Depth
        };


        //-----------------------------------------*public params*---------------------------------------------------
        [Header("Attach")]
        public Camera m_Camera = null;

        [Header("Render Option")]
        public EReflectMode m_ReflMode = EReflectMode.ReflM_SSR;
        public ERefractMode m_RefrMode = ERefractMode.RefrM_Depth;

        [Header("Blur")]
        [SerializeField]
        [Range(1, 4)]
        [Tooltip("Number of blur passes")]
        public int m_Downscale = 2;

        [SerializeField]
        [Range(0, 8)]
        [Tooltip("Number of iterations in one pass")]
        public int m_Iterations = 2;
        [SerializeField]
        public bool m_StretchEdge = true;

        [SerializeField]
        [Range(1, 10)]
        public int m_StretchEdgeDis = 5;

        [SerializeField]
        public bool m_BlurEdge = true;

        [Header("Ray Marching")]
        [SerializeField]
        [Range(8, 256)]
        [Tooltip("Raymarching iterations. The more you set, the better result will be (and the slower perf)")]
        public int m_MaxRaymarchIterations = 32;

        [SerializeField]
        [Range(50, 200)]
        [Tooltip("Raymarching Distance. The more you set, the better result will be (and the slower perf)")]
        public int m_MaximumMarchDistance = 100;

        [SerializeField]
        [Range(8, 32)]
        [Tooltip("Raymarching Step Size.")]
        public float m_Bandwidth = 16;

        [Tooltip("Raymarching Noise Texture.")]
        public Texture2D m_NoiseTexture = null;

        [SerializeField]
        [Range(256, 1024)]
        [Tooltip("SSR Render Texture Size.")]
        public int m_SSRTextureSize = 512;

        [Header("Planer Reflect")]
        public int m_TextureSize = 256;
        public float clipPlaneOffset = 0.07f;
        public LayerMask reflectLayers = -1;

        //-----------------------------------------*private params*---------------------------------------------------
        // ssr
        private Shader ssrShader = null;
        private Shader blurShader = null;
        private Shader blurEdgeShader = null;
        private Shader edgeStretchShader = null;

        private RenderTexture m_ColorRenderTexture = null;
        private int m_OldSSRTextureSize = 0;

        static Material m_MaterialSSR = null;
        protected Material MaterialSSR
        {
            get
            {
                if (!m_MaterialSSR && ssrShader && m_Camera)
                {
                    Debug.Assert(m_Camera.actualRenderingPath == RenderingPath.Forward );
                    m_MaterialSSR = new Material(ssrShader);
                    m_MaterialSSR.hideFlags = HideFlags.DontSave;
                }
                return m_MaterialSSR;
            }
        }

        static Material m_MaterialBlur = null;
        protected Material MaterialBlur
        {
            get
            {
                if (!m_MaterialBlur && blurShader)
                {
                    m_MaterialBlur = new Material(blurShader);
                    m_MaterialBlur.hideFlags = HideFlags.DontSave;
                }
                return m_MaterialBlur;
            }
        }

        static Material m_MaterialEdgeBlur = null;
        protected Material MaterialEdgeBlur
        {
            get
            {
                if (!m_MaterialEdgeBlur && blurEdgeShader)
                {
                    m_MaterialEdgeBlur = new Material(blurEdgeShader);
                    m_MaterialEdgeBlur.hideFlags = HideFlags.DontSave;
                }
                return m_MaterialEdgeBlur;
            }
        }

        static Material m_MaterialEdgeStretch = null;
        protected Material MaterialEdgeStretch
        {
            get
            {
                if (!m_MaterialEdgeStretch && edgeStretchShader)
                {
                    m_MaterialEdgeStretch = new Material(edgeStretchShader);
                    m_MaterialEdgeStretch.hideFlags = HideFlags.DontSave;
                }
                return m_MaterialEdgeStretch;
            }
        }

        // planer reflect
        private RenderTexture m_PlanerReflectionTexture = null;
        private Camera m_PlanerReflectionCamera = null;
        private int m_OldReflectionTextureSize = 0;
        CommandBuffer bufGrabDepth;
        CommandBuffer bufSSR;
        CommandBuffer bufPostWaterRender;

        // water instance
        private List<WaterInstance> m_WaterInstances = new List<WaterInstance>();


        //--------------------------------------------------------------------------------------------
        private void Update()
        {
            bool act = gameObject.activeInHierarchy && enabled;
            if (!act || !m_Camera)
            {
                return;
            }

            if (!m_ColorRenderTexture || m_SSRTextureSize != m_OldSSRTextureSize)
            {
                //m_ColorRenderTexture = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.Default);
                m_ColorRenderTexture = new RenderTexture(m_SSRTextureSize, m_SSRTextureSize, 0, RenderTextureFormat.Default);
                if (!m_ColorRenderTexture.Create())
                {
                    DestroyImmediate(m_ColorRenderTexture);
                    m_ColorRenderTexture = null;
                }
                else
                {
                    m_OldSSRTextureSize = m_SSRTextureSize;
                }
            }

        }

        public void LateUpdate()
        {
            if (bufGrabDepth == null || bufSSR == null || bufPostWaterRender == null)
                return;

            bufGrabDepth.Clear();
            bufSSR.Clear();
            bufPostWaterRender.Clear();

            if (m_RefrMode == ERefractMode.RefrM_Depth)
            {
                AddGrabDepthCmdBuffer();

                if (m_ReflMode == EReflectMode.ReflM_SSR)
                {
                    AddSSRCmdBuffer();
                }
                else if (m_ReflMode == EReflectMode.ReflM_Planer) // 平面真反射
                {
                    AndPlanerReflector();
                }
            }
            else // m_RefrMode == ERefractMode.RefrM_Simple 这里反射只设置cube。
            {
                m_RefrMode = ERefractMode.RefrM_Simple;
                m_ReflMode = EReflectMode.ReflM_Cube;
            }
        }

        private void OnEnable()
        {
            bufGrabDepth = new CommandBuffer();
            bufGrabDepth.name = "Grab Depth";
            bufSSR = new CommandBuffer();
            bufSSR.name = "SSR";
            bufPostWaterRender = new CommandBuffer();
            bufPostWaterRender.name = "After Render Water";

            m_Camera.AddCommandBuffer(CameraEvent.AfterSkybox, bufGrabDepth);
            m_Camera.AddCommandBuffer(CameraEvent.AfterSkybox, bufSSR);
            m_Camera.AddCommandBuffer(CameraEvent.BeforeImageEffects, bufPostWaterRender);


            if (ssrShader == null)
                ssrShader = Shader.Find("Hidden/SSRShader");
            if (ssrShader == null)
            {
                enabled = false;
                Debug.LogError("[Water SSR] Please, import SSRShader shader, I cannot found it");
                return;
            }

            if (blurShader == null)
                blurShader = Shader.Find("Hidden/SSRBlurShader");
            if (blurShader == null)
            {
                enabled = false;
                Debug.LogError("[Water SSR] Please, import SSRBlurShader shader, I cannot found it");
                return;
            }

            if (blurEdgeShader == null)
                blurEdgeShader = Shader.Find("Hidden/SSRBlurEdgeShader");
            if (blurEdgeShader == null)
            {
                enabled = false;
                Debug.LogError("[Water SSR] Please, import SSRBlurEdgeShader shader, I cannot found it");
                return;
            }

            if (edgeStretchShader == null)
                edgeStretchShader = Shader.Find("Hidden/SSREdgeStretchShader");
            if (edgeStretchShader == null)
            {
                enabled = false;
                Debug.LogError("[Water SSR] Please, import SSREdgeStretchShader shader, I cannot found it");
                return;
            }

            if(!m_ColorRenderTexture)
            {
                //m_ColorRenderTexture = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.Default);
                m_ColorRenderTexture = new RenderTexture(m_SSRTextureSize, m_SSRTextureSize, 0, RenderTextureFormat.Default);
                if (!m_ColorRenderTexture.Create())
                {
                    DestroyImmediate(m_ColorRenderTexture);
                    m_ColorRenderTexture = null;
                }
                else
                {
                    m_OldSSRTextureSize = m_SSRTextureSize;
                }
            }
        }

        private void OnDisable()
        {
            if (m_Camera != null)
            {
                m_Camera.RemoveCommandBuffer(CameraEvent.AfterSkybox, bufGrabDepth);
                m_Camera.RemoveCommandBuffer(CameraEvent.AfterSkybox, bufSSR);
                m_Camera.RemoveCommandBuffer(CameraEvent.BeforeImageEffects, bufPostWaterRender);
            }

            if (m_MaterialSSR)
            {
                DestroyImmediate(m_MaterialSSR);
                m_MaterialSSR = null;
            }

            if (m_MaterialBlur)
            {
                DestroyImmediate(m_MaterialBlur);
                m_MaterialBlur = null;
            }

            if (m_MaterialEdgeBlur)
            {
                DestroyImmediate(m_MaterialEdgeBlur);
                m_MaterialEdgeBlur = null;
            }

            if (m_MaterialEdgeStretch)
            {
                DestroyImmediate(m_MaterialEdgeStretch);
                m_MaterialEdgeStretch = null;
            }

            if(m_ColorRenderTexture)
            {
                DestroyImmediate(m_ColorRenderTexture);
                m_ColorRenderTexture = null;
            }

            if(m_PlanerReflectionCamera)
            {
                DestroyImmediate(m_PlanerReflectionCamera.gameObject);
                m_PlanerReflectionCamera = null;
            }

            if(m_PlanerReflectionTexture)
            {
                DestroyImmediate(m_PlanerReflectionTexture);
                m_PlanerReflectionTexture = null;
            }

            //GameObject.FindObjectsOfType<>
        }

        // Performs one blur iteration.
        public void FourTapCone(int source, int dest, int iteration, CommandBuffer cmdBuffer)
        {
            cmdBuffer.Blit(source, dest, this.MaterialBlur);
        }

        // Downsamples the texture to a quarter resolution.
        private void DownSample4x(RenderTexture source, int dest, CommandBuffer cmdBuffer)
        {
            cmdBuffer.Blit(source, dest, this.MaterialBlur);
        }

        private void AddGrabDepthCmdBuffer()
        {
            // copy screen into temporary RT
            RenderTexture depthTexture = ((CameraRenderTargetReplace)m_Camera.GetComponent(typeof(CameraRenderTargetReplace))).DepthRenderTexture;
            int screenDepthCopyID = Shader.PropertyToID("_ScreenCopyDepthTexture");
            bufGrabDepth.GetTemporaryRT(screenDepthCopyID, -1, -1, 0, FilterMode.Point, RenderTextureFormat.RFloat);
            bufGrabDepth.Blit(depthTexture, screenDepthCopyID);
            bufGrabDepth.SetGlobalTexture("_CameraCopyDepthTexture", screenDepthCopyID);
        }

        private void AddSSRCmdBuffer()
        {
            bufSSR.SetRenderTarget(m_ColorRenderTexture);
            // SSR
            RenderTexture colorTexture = ((CameraRenderTargetReplace)m_Camera.GetComponent(typeof(CameraRenderTargetReplace))).ColorRenderTexture;
            this.MaterialSSR.SetTexture("_MainTex", colorTexture);

            Vector4 _Params = new Vector4(0.0f, 0.0f, m_MaximumMarchDistance, 1.0f);
            float noiseTexWidth = 256.0f;
            if (m_NoiseTexture)
                noiseTexWidth = m_NoiseTexture.width;
            Vector4 _Params2 = new Vector4((float)m_ColorRenderTexture.width / (float)m_ColorRenderTexture.height, (float)m_ColorRenderTexture.height / noiseTexWidth, m_Bandwidth, m_MaxRaymarchIterations);
            this.MaterialSSR.SetVector("_Params", _Params);
            this.MaterialSSR.SetVector("_Params2", _Params2);
            this.MaterialSSR.SetTexture("_Noise", m_NoiseTexture);

            //循环，渲染不同水面
            foreach(var oneWater in m_WaterInstances)
            {
                if(oneWater)
                {
                    Mesh mesh = oneWater.gameObject.GetComponent<MeshFilter>().sharedMesh;
                    bufSSR.DrawMesh(mesh, oneWater.gameObject.transform.localToWorldMatrix, m_MaterialSSR);
                }
            }

            // Blur
            //_BlurOffsets
            //float off = 0.5f + settings.blurSpread;
            Vector4 bluroffsets = new Vector4(1.0f, 1.0f, 1.0f, 1.0f);
            this.MaterialBlur.SetVector("_BlurOffsets", bluroffsets);
            this.MaterialEdgeBlur.SetVector("_BlurOffsets", bluroffsets);

            float tStretchEdgeDis = m_StretchEdgeDis * 1.0f;
            Vector4 bluroffsets_stretch = new Vector4(tStretchEdgeDis, tStretchEdgeDis, 1.0f, 1.0f);
            this.MaterialEdgeStretch.SetVector("_BlurOffsets", bluroffsets_stretch);

            bufSSR.SetRenderTarget(colorTexture);
            int rtW = m_ColorRenderTexture.width;
            int rtH = m_ColorRenderTexture.height;
            int blurTextureID = -1;
            if (m_Iterations != 0 && m_Downscale > 1)
            {
                blurTextureID = Shader.PropertyToID("_BlurTexture" + m_Iterations);
                bufSSR.GetTemporaryRT(blurTextureID, rtW / m_Downscale, rtH / m_Downscale, 0);
                DownSample4x(m_ColorRenderTexture, blurTextureID, bufSSR);

                //Blur the small texture
                for (int i = 0; i < m_Iterations; i++)
                {
                    int blurTmpTextureID = Shader.PropertyToID("_BlurTexture" + i);
                    bufSSR.GetTemporaryRT(blurTmpTextureID, rtW / m_Downscale, rtH / m_Downscale, 0);
                    FourTapCone(blurTextureID, blurTmpTextureID, i, bufSSR);
                    bufSSR.ReleaseTemporaryRT(blurTextureID);
                    blurTextureID = blurTmpTextureID;
                }

                // edge stretch
                if(m_StretchEdge)
                {
                    int blurTmpTextureID = Shader.PropertyToID("_EdgeStretchTexture");
                    bufSSR.GetTemporaryRT(blurTmpTextureID, rtW / m_Downscale, rtH / m_Downscale, 0);
                    bufSSR.Blit(blurTextureID, blurTmpTextureID, this.MaterialEdgeStretch);
                    bufSSR.ReleaseTemporaryRT(blurTextureID);
                    blurTextureID = blurTmpTextureID;
                }

                // blur edge
                if(m_BlurEdge)
                {
                    int blurTmpTextureID = Shader.PropertyToID("_BlurEdgeTexture");
                    bufSSR.GetTemporaryRT(blurTmpTextureID, rtW / m_Downscale, rtH / m_Downscale, 0);
                    bufSSR.Blit(blurTextureID, blurTmpTextureID, this.MaterialEdgeBlur);
                    bufSSR.ReleaseTemporaryRT(blurTextureID);
                    blurTextureID = blurTmpTextureID;
                }

                //buf.ReleaseTemporaryRT(blurTextureID);
                bufSSR.SetGlobalTexture("_ReflectTexture", blurTextureID);
            }
            else
            {
                bufSSR.SetGlobalTexture("_ReflectTexture", m_ColorRenderTexture);
            }

            // post render 释放temp render texture
            if (m_Iterations != 0 && m_Downscale > 1)
            {
                bufPostWaterRender.ReleaseTemporaryRT(blurTextureID);
            }
        }

        private void AndPlanerReflector()
        {
            if (!m_PlanerReflectionCamera) // catch both not-in-dictionary and in-dictionary-but-deleted-GO
            {
                GameObject go = new GameObject("Water Refl Camera id" + GetInstanceID() + " for " + m_Camera.GetInstanceID(), typeof(Camera), typeof(Skybox));
                m_PlanerReflectionCamera = go.GetComponent<Camera>();
                m_PlanerReflectionCamera.enabled = false;
                m_PlanerReflectionCamera.transform.position = transform.position;
                m_PlanerReflectionCamera.transform.rotation = transform.rotation;
                m_PlanerReflectionCamera.gameObject.AddComponent<FlareLayer>();
                go.hideFlags = HideFlags.HideAndDontSave;
            }

            // Reflection render texture
            if (!m_PlanerReflectionTexture || m_OldReflectionTextureSize != m_TextureSize)
            {
                if (m_PlanerReflectionTexture)
                {
                    DestroyImmediate(m_PlanerReflectionTexture);
                }
                m_PlanerReflectionTexture = new RenderTexture(m_TextureSize, m_TextureSize, 16);
                m_PlanerReflectionTexture.name = "__WaterReflection" + GetInstanceID();
                m_PlanerReflectionTexture.isPowerOfTwo = true;
                m_PlanerReflectionTexture.hideFlags = HideFlags.DontSave;
                m_OldReflectionTextureSize = m_TextureSize;
            }

            // find out the reflection plane: position and normal in world space
            Vector3 pos = transform.position;
            Vector3 normal = transform.up;

            UpdateCameraModes(m_Camera, m_PlanerReflectionCamera);

            // Reflect camera around reflection plane
            float d = -Vector3.Dot(normal, pos) - clipPlaneOffset;
            Vector4 reflectionPlane = new Vector4(normal.x, normal.y, normal.z, d);

            Matrix4x4 reflection = Matrix4x4.zero;
            CalculateReflectionMatrix(ref reflection, reflectionPlane);
            Vector3 oldpos = m_Camera.transform.position;
            Vector3 newpos = reflection.MultiplyPoint(oldpos);
            m_PlanerReflectionCamera.worldToCameraMatrix = m_Camera.worldToCameraMatrix * reflection;

            // Setup oblique projection matrix so that near plane is our reflection
            // plane. This way we clip everything below/above it for free.
            Vector4 clipPlane = CameraSpacePlane(m_PlanerReflectionCamera, pos, normal, 1.0f);
            m_PlanerReflectionCamera.projectionMatrix = m_Camera.CalculateObliqueMatrix(clipPlane);

            // Set custom culling matrix from the current camera
            //m_PlanerReflectionCamera.cullingMatrix = m_Camera.projectionMatrix * m_Camera.worldToCameraMatrix;

            m_PlanerReflectionCamera.cullingMask = ~(1 << 4) & reflectLayers.value; // never render water layer
            m_PlanerReflectionCamera.targetTexture = m_PlanerReflectionTexture;
            bool oldCulling = GL.invertCulling;
            GL.invertCulling = !oldCulling;
            m_PlanerReflectionCamera.transform.position = newpos;
            Vector3 euler = m_Camera.transform.eulerAngles;
            m_PlanerReflectionCamera.transform.eulerAngles = new Vector3(-euler.x, euler.y, euler.z);
            m_PlanerReflectionCamera.Render();
            m_PlanerReflectionCamera.transform.position = oldpos;
            GL.invertCulling = oldCulling;
            Shader.SetGlobalTexture("_ReflectTexture", m_PlanerReflectionTexture);
            //GetComponent<Renderer>().sharedMaterial.SetTexture("_ReflectTexture", m_PlanerReflectionTexture);
        }

        private void UpdateCameraModes(Camera src, Camera dest)
        {
            if (dest == null)
            {
                return;
            }
            // set water camera to clear the same way as current camera
            dest.clearFlags = src.clearFlags;
            dest.backgroundColor = src.backgroundColor;
            if (src.clearFlags == CameraClearFlags.Skybox)
            {
                Skybox sky = src.GetComponent<Skybox>();
                Skybox mysky = dest.GetComponent<Skybox>();
                if (!sky || !sky.material)
                {
                    mysky.enabled = false;
                }
                else
                {
                    mysky.enabled = true;
                    mysky.material = sky.material;
                }
            }
            // update other values to match current camera.
            // even if we are supplying custom camera&projection matrices,
            // some of values are used elsewhere (e.g. skybox uses far plane)
            dest.farClipPlane = src.farClipPlane;
            dest.nearClipPlane = src.nearClipPlane;
            dest.orthographic = src.orthographic;
            dest.fieldOfView = src.fieldOfView;
            dest.aspect = src.aspect;
            dest.orthographicSize = src.orthographicSize;
        }

        Vector4 CameraSpacePlane(Camera cam, Vector3 pos, Vector3 normal, float sideSign)
        {
            Vector3 offsetPos = pos + normal * clipPlaneOffset;
            Matrix4x4 m = cam.worldToCameraMatrix;
            Vector3 cpos = m.MultiplyPoint(offsetPos);
            Vector3 cnormal = m.MultiplyVector(normal).normalized * sideSign;
            return new Vector4(cnormal.x, cnormal.y, cnormal.z, -Vector3.Dot(cpos, cnormal));
        }

        static void CalculateReflectionMatrix(ref Matrix4x4 reflectionMat, Vector4 plane)
        {
            reflectionMat.m00 = (1F - 2F * plane[0] * plane[0]);
            reflectionMat.m01 = (-2F * plane[0] * plane[1]);
            reflectionMat.m02 = (-2F * plane[0] * plane[2]);
            reflectionMat.m03 = (-2F * plane[3] * plane[0]);

            reflectionMat.m10 = (-2F * plane[1] * plane[0]);
            reflectionMat.m11 = (1F - 2F * plane[1] * plane[1]);
            reflectionMat.m12 = (-2F * plane[1] * plane[2]);
            reflectionMat.m13 = (-2F * plane[3] * plane[1]);

            reflectionMat.m20 = (-2F * plane[2] * plane[0]);
            reflectionMat.m21 = (-2F * plane[2] * plane[1]);
            reflectionMat.m22 = (1F - 2F * plane[2] * plane[2]);
            reflectionMat.m23 = (-2F * plane[3] * plane[2]);

            reflectionMat.m30 = 0F;
            reflectionMat.m31 = 0F;
            reflectionMat.m32 = 0F;
            reflectionMat.m33 = 1F;
        }

        public void AddOneWater(WaterInstance oneWater)
        {
            if(m_WaterInstances == null)
            {
                m_WaterInstances = new List<WaterInstance>();
            }
            m_WaterInstances.Add(oneWater);
        }

        public void RemoveOneWater(WaterInstance oneWater)
        {
            m_WaterInstances.Remove(oneWater);
        }
    }
}


