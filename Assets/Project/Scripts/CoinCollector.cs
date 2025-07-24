using UnityEngine;
using TMPro;

public class CoinCollector : MonoBehaviour
{
    [SerializeField] private GameObject player;
    [SerializeField] private TextMeshProUGUI coinText;

    [SerializeField] private GameObject[] coins;
    [SerializeField] private int coinCount = 0;
    [SerializeField] private int nextCoinIndex = 0;

    private const float pickupDistance = 1.5f;
    private readonly float pickupDistanceSqr = pickupDistance * pickupDistance;

    private void Start()
    {
        coins = GameObject.FindGameObjectsWithTag("Coin");

        if (coins.Length == 0)
        {
            Debug.LogWarning("Монеты с тегом 'Coin' не найдены!");
            return;
        }

        for (int i = 0; i < coins.Length; i++)
        {
            coins[i].SetActive(i == 0);
        }

        UpdateCoinUI();
    }

    private void Update()
    {
        if (coins.Length == 0) return;

        GameObject currentCoin = coins[nextCoinIndex];
        if (currentCoin != null && currentCoin.activeSelf)
        {
            float sqrDistance = (player.transform.position - currentCoin.transform.position).sqrMagnitude;

            if (sqrDistance < pickupDistanceSqr)
            {
                CollectCoin(currentCoin);
            }
        }
    }

    private void CollectCoin(GameObject coin)
    {
        coin.SetActive(false);
        coinCount++;
        UpdateCoinUI();

        nextCoinIndex = (nextCoinIndex + 1) % coins.Length;
        coins[nextCoinIndex].SetActive(true);
    }

    private void UpdateCoinUI()
    {
        if (coinText != null)
        {
            coinText.text = $"Coins: {coinCount}";
        }
    }
}
