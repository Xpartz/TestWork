using UnityEngine;

public class FireflyFollower : MonoBehaviour
{
    [Header("Movement Settings")]
    [SerializeField] private Transform target;
    [SerializeField] private float followSpeed = 2f;
    [SerializeField] private float orbitRadius = 1.5f;
    [SerializeField] private float orbitSpeed = 50f;
    [SerializeField] private float moveThreshold = 0.01f;

    private Vector3 lastTargetPosition;
    private float orbitAngle;

    void Start()
    {
        if (target != null)
        {
            lastTargetPosition = target.position;
        }
    }

    void Update()
    {
        if (target == null) return;

        Vector3 targetMovement = target.position - lastTargetPosition;
        bool isMoving = targetMovement.magnitude > moveThreshold;

        if (isMoving)
        {
            transform.position = Vector3.Lerp(transform.position, target.position, Time.deltaTime * followSpeed);
        }
        else
        {
            orbitAngle += orbitSpeed * Time.deltaTime;
            float rad = orbitAngle * Mathf.Deg2Rad;

            Vector3 offset = new Vector3(Mathf.Cos(rad), 0, Mathf.Sin(rad)) * orbitRadius;
            Vector3 desiredPosition = target.position + offset;

            transform.position = Vector3.Lerp(transform.position, desiredPosition, Time.deltaTime * followSpeed);
        }

        transform.LookAt(target.position);
        lastTargetPosition = target.position;
    }
}
