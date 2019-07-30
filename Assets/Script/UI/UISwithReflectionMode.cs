using System.Collections;
using System.Collections.Generic;
using AWater;
using UnityEngine;
using UnityEngine.UI;

public class UISwithReflectionMode : MonoBehaviour
{
    public WaterController water;
    public Button btn;
    public Text text;
    private void Awake()
    {
        if (btn == null)
        {
            btn = GetComponent<Button>();
            text = btn.GetComponentInChildren<Text>();
            text.text = water.m_ReflMode.ToString();
        }
        if (btn != null)
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
        if (water != null)
        {
            water.m_ReflMode = (WaterController.EReflectMode)(((int)water.m_ReflMode + 1) % (int)(WaterController.EReflectMode.ReflM_Planer + 1));
            text.text = water.m_ReflMode.ToString();
        }
    }
}
