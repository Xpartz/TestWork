using UnityEngine;

public class RotatingFloatingObject : MonoBehaviour
{
    [Header("Rotation Settings")]
    [SerializeField] private float rotationSpeed = 30f;

    [Header("Floating Settings")]
    [SerializeField] private AnimationCurve floatCurve = AnimationCurve.EaseInOut(0, 0, 1, 1);
    [SerializeField] private float floatAmplitude = 0.5f;
    [SerializeField] private float floatSpeed = 1f;

    [Header("Particle Settings")]
    [SerializeField] private ParticleSystem ps;
    [SerializeField] private float alphaMultiplier = 1f;
    [SerializeField] private Color baseColor = Color.white;

    private float baseY;
    private float timeOffset;
    private ParticleSystem.Particle[] particles;

    private void Awake()
    {
        baseY = transform.position.y;
        timeOffset = Random.Range(0f, 100f);
    }

    private void FixedUpdate()
    {
        transform.Rotate(Vector3.up, rotationSpeed * Time.deltaTime);

        float time = (Time.time + timeOffset) * floatSpeed;
        float curveValue = floatCurve.Evaluate(time % 1f);
        float yOffset = curveValue * floatAmplitude;
        Vector3 position = transform.position;
        position.y = baseY + yOffset;
        transform.position = position;

        if (ps != null)
        {
            if (particles == null || particles.Length < ps.main.maxParticles)
                particles = new ParticleSystem.Particle[ps.main.maxParticles];

            int count = ps.GetParticles(particles);

            float invertedAlpha = Mathf.Clamp01(1f - curveValue * 2) * alphaMultiplier;

            for (int i = 0; i < count; i++)
            {
                Color color = baseColor;
                color.a = invertedAlpha;
                particles[i].startColor = color;
            }

            ps.SetParticles(particles, count);
        }

    }
}
