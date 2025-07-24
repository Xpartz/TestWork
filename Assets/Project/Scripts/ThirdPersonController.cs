using UnityEngine;
using UnityEngine.InputSystem;

[RequireComponent(typeof(CharacterController))]
public class ThirdPersonController : MonoBehaviour
{
    private static readonly int ForwardHash = Animator.StringToHash("Forward");
    private static readonly int StrafeHash = Animator.StringToHash("Strafe");
    private static readonly int JumpHash = Animator.StringToHash("Jump");
    private static readonly int LocomotionHash = Animator.StringToHash("Locomotion");

    private CharacterController controller;
    [SerializeField] private Animator animator;
    private Transform cameraTransform;

    private InputSystem_Actions inputActions;
    private Vector2 moveInput;
    private bool jumpPressed;

    [Header("Movement Settings")]
    [SerializeField] private float moveSpeed = 5f;
    [SerializeField] private float rotationSpeed = 10f;
    [SerializeField] private float gravity = -9.81f;
    [SerializeField] private float jumpHeight = 2f;

    private float verticalVelocity;
    private Vector3 velocity;
    private Vector3 lastMoveDirection;
    private bool jumpedFromStationary = false;

    private void Awake()
    {
        controller = GetComponent<CharacterController>();

        if (animator == null)
        {
            animator = GetComponentInChildren<Animator>();
            if (animator == null)
                Debug.LogWarning("Animator не найден");
        }

        cameraTransform = Camera.main != null ? Camera.main.transform : null;
        if (cameraTransform == null)
            Debug.LogWarning("Main Camera не найдена");

        inputActions = new InputSystem_Actions();
    }

    private void OnEnable()
    {
        inputActions.Enable();
        inputActions.Player.Move.performed += OnMove;
        inputActions.Player.Move.canceled += OnMove;
        inputActions.Player.Jump.performed += OnJump;
    }

    private void OnDisable()
    {
        inputActions.Player.Move.performed -= OnMove;
        inputActions.Player.Move.canceled -= OnMove;
        inputActions.Player.Jump.performed -= OnJump;
        inputActions.Disable();
    }

    private void OnMove(InputAction.CallbackContext ctx)
    {
        moveInput = ctx.ReadValue<Vector2>();
    }

    private void OnJump(InputAction.CallbackContext ctx)
    {
        if (ctx.performed)
            jumpPressed = true;
    }

    private void Update()
    {
        HandleMovement();
        HandleGravityAndJump();
        ApplyFinalMovement();
        UpdateAnimator();
    }

    private void HandleMovement()
    {
        Vector3 inputDir = new Vector3(moveInput.x, 0f, moveInput.y).normalized;

        bool isGrounded = controller.isGrounded;

        if (inputDir.magnitude >= 0.1f && cameraTransform != null)
        {
            if (isGrounded || !jumpedFromStationary)
            {
                Vector3 camF = cameraTransform.forward; camF.y = 0f; camF.Normalize();
                Vector3 camR = cameraTransform.right; camR.y = 0f; camR.Normalize();

                Vector3 moveDir = camF * inputDir.z + camR * inputDir.x;

                Quaternion targetRot = Quaternion.LookRotation(moveDir);
                transform.rotation = Quaternion.Slerp(transform.rotation, targetRot, rotationSpeed * Time.deltaTime);

                lastMoveDirection = moveDir * moveSpeed;
            }
        }
        else
        {
            if (isGrounded)
            {
                lastMoveDirection = Vector3.zero;
            }
        }
    }

    private void HandleGravityAndJump()
    {
        bool isGrounded = controller.isGrounded;

        if (isGrounded && verticalVelocity < 0f)
        {
            verticalVelocity = -2f;
            jumpedFromStationary = false;
        }

        if (jumpPressed && isGrounded)
        {
            verticalVelocity = Mathf.Sqrt(jumpHeight * -2f * gravity);
            jumpPressed = false;

            jumpedFromStationary = moveInput.sqrMagnitude < 0.01f;

            if (animator != null)
                animator.SetTrigger(JumpHash);
        }

        verticalVelocity += gravity * Time.deltaTime;
        velocity.y = verticalVelocity;
    }

    private void ApplyFinalMovement()
    {
        Vector3 totalMovement = lastMoveDirection;
        totalMovement.y = velocity.y;
        controller.Move(totalMovement * Time.deltaTime);
    }

    private void UpdateAnimator()
    {
        if (animator == null) return;

        Vector3 localMove = transform.InverseTransformDirection(lastMoveDirection);
        float forward = Mathf.Clamp(localMove.z / moveSpeed, -1f, 1f);
        float strafe = Mathf.Clamp(localMove.x / moveSpeed, -1f, 1f);

        animator.SetFloat(ForwardHash, forward, 0.1f, Time.deltaTime);
        animator.SetFloat(StrafeHash, strafe, 0.1f, Time.deltaTime);

        bool isMoving = moveInput.sqrMagnitude > 0.01f;
        animator.SetBool(LocomotionHash, isMoving);
    }
}
