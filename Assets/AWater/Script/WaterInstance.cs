using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;

namespace AWater
{
    [ExecuteInEditMode]
    public class WaterInstance : MonoBehaviour
    {
        [Tooltip("Water Controller")]
        public WaterController m_WaterController;

        // Start is called before the first frame update
        void Start()
        {

        }

        // Update is called once per frame
        void Update()
        {

        }

        public void OnEnable()
        {
            if(m_WaterController)
            {
                m_WaterController.AddOneWater(this);
            }
        }

        public void OnDisable()
        {
            if(m_WaterController)
            {
                m_WaterController.RemoveOneWater(this);
            }
        }

        public void OnWillRenderObject()
        {
#if UNITY_EDITOR
            if (Application.isPlaying)
            {
                if (Camera.current != m_WaterController.m_Camera) //给scene相机添加
                {
                    Camera tmpCamera = Camera.current;
                    if (tmpCamera.cameraType == CameraType.SceneView)
                    {
                        Shader.SetGlobalTexture("_CameraCopyDepthTexture", Texture2D.blackTexture);
                    }
                }
            }
#endif

            // Water Composite Material
            Material matRender = GetComponent<Renderer>().sharedMaterial;
            if (!matRender)
                return;

            if (!m_WaterController)
                return;


            if (m_WaterController.m_RefrMode == WaterController.ERefractMode.RefrM_Depth && m_WaterController.m_ReflMode == WaterController.EReflectMode.ReflM_Cube)
            {
                matRender.DisableKeyword("WATER_NOZBUFFER");
                matRender.EnableKeyword("WATER_HASZBUFFER");
                matRender.EnableKeyword("WATER_REFL_CUBE");
                matRender.DisableKeyword("WATER_REFL_SSR");
                matRender.DisableKeyword("WATER_REFL_PLANER");
            }
            else if (m_WaterController.m_RefrMode == WaterController.ERefractMode.RefrM_Depth && m_WaterController.m_ReflMode == WaterController.EReflectMode.ReflM_SSR)
            {
                matRender.DisableKeyword("WATER_NOZBUFFER");
                matRender.EnableKeyword("WATER_HASZBUFFER");
                matRender.DisableKeyword("WATER_REFL_CUBE");
                matRender.EnableKeyword("WATER_REFL_SSR");
                matRender.DisableKeyword("WATER_REFL_PLANER");
            }
            else if (m_WaterController.m_RefrMode == WaterController.ERefractMode.RefrM_Depth && m_WaterController.m_ReflMode == WaterController.EReflectMode.ReflM_Planer)
            {
                matRender.DisableKeyword("WATER_NOZBUFFER");
                matRender.EnableKeyword("WATER_HASZBUFFER");
                matRender.DisableKeyword("WATER_REFL_CUBE");
                matRender.DisableKeyword("WATER_REFL_SSR");
                matRender.EnableKeyword("WATER_REFL_PLANER");
            }
            else
            {
                matRender.EnableKeyword("WATER_NOZBUFFER");
                matRender.DisableKeyword("WATER_HASZBUFFER");
                matRender.EnableKeyword("WATER_REFL_CUBE");
                matRender.DisableKeyword("WATER_REFL_SSR");
                matRender.DisableKeyword("WATER_REFL_PLANER");
            }

            Vector4 waveSpeed = matRender.GetVector("WaveSpeed");
            float waveScale = matRender.GetFloat("_WaveScale");
            Vector4 waveScale4 = new Vector4(waveScale, waveScale, waveScale * 0.4f, waveScale * 0.45f);

            // Time since level load, and do intermediate calculations with doubles
            double t = Time.timeSinceLevelLoad / 20.0;
            Vector4 offsetClamped = new Vector4(
                (float)Math.IEEERemainder(waveSpeed.x * waveScale4.x * t, 1.0),
                (float)Math.IEEERemainder(waveSpeed.y * waveScale4.y * t, 1.0),
                (float)Math.IEEERemainder(waveSpeed.z * waveScale4.z * t, 1.0),
                (float)Math.IEEERemainder(waveSpeed.w * waveScale4.w * t, 1.0)
                );

            matRender.SetVector("_WaveOffset", offsetClamped);
            matRender.SetVector("_WaveScale4", waveScale4);
        }
    }
}

