Cryptocurrency Prices From CoinLore
主页
新闻
排行
交易
Tools
登录
USD
搜寻货币
加密货币:14,471 市场:33,121  市值:$2,579,503,640,411 24小时 交易量:$126,770,073,624 比特币优势:59.5%
免费加密货币 API，提供实时加密市场数据
CoinLore 为开发者、交易员、研究人员以及构建加密应用、仪表盘、筛选器和市场数据工具的企业提供免费公开的加密货币 API。该 API 公开开放，无需注册，可提供超过 14470 种币和 300 多家交易所的实时加密市场数据。

通过 CoinLore 加密 API，你可以从统一的公开端点访问实时价格、市值、交易量、币种元数据、交易所市场、社交统计、movers 以及 365 天 OHLCV 历史数据。

这个免费的加密 API 为快速集成而设计，不需要 API key。虽然没有严格的速率限制，但为了稳定和公平使用，我们建议大约每秒 1 次请求。主 API 域名是 api.coinlore.net。

下面你可以查看当前支持的 API 端点，包括实时价格、历史加密数据、OHLCV K 线、市场分析、交易所交易对和社交数据。每个端点都包含请求示例、返回字段和多种编程语言的代码示例。

如果你需要 API 帮助或想分享反馈，请联系 contact@coinlore.com。

端点
▶ Playground
/api/global/
/api/assets/
/api/tickers/
/api/movers/
/api/ticker/
/api/coin/info/
/api/coin/ohlcv/
/api/coin/markets/
/api/exchanges/
/api/exchange/
/api/coin/social_stats/
加密货币 API 端点
API 端点	说明
/api/global/	获取全局加密货币统计数据，包括币种总数、总市值、BTC 占比、总交易量、ATH 市值等。
/api/assets/	所有币种的轻量列表（id, symbol, name, nameid, rank）。适合在没有重分页的情况下构建查询表、自动补全和币种选择器。
/api/tickers/	获取多个币种的 ticker 数据，并按市值排序。包含 name、ID、symbol、price、price change、market cap、volume 和 supply。
/api/movers/	24 小时成交量至少为 $50k 的前 20 名上涨币和前 20 名下跌币。可按 1h、24h（默认）或 7d 的价格变化排序。
/api/ticker/?id={ID}	使用 /api/tickers/ 中的 ID 获取单个币种的 ticker 数据。包含 name、ID、symbol、price、change、market cap、volume 和 supply。
/api/coin/info/?id={ID}	单个币种的静态元数据：logo、ATH、supply、launch date、website、twitter、explorer、platform 和 first price date。
/api/coin/ohlcv/?coin={ID}	获取单个币种 365 天的日 OHLCV 历史数据，包括 timestamp、open、high、low、close 和 volume。
/api/coin/markets/?id={ID}	获取单个币种的前 50 个交易所和市场。
/api/exchanges/	获取我们平台上列出的所有交易所。
/api/exchange/?id={ID}	使用 /api/exchanges/ 中的 ID 获取单个交易所。返回交易所信息和前 100 个交易对。
/api/coin/social_stats/?id={ID}	单个币种的 Twitter 和 Reddit 社交统计。
▶
实时 API Playground
立即试用 - 无需 API key
选择一个端点，填写所需参数，并直接向 CoinLore API 发起实时请求。响应将实时显示在下方。

端点

GET /api/global/
▶ 发送
URL
https://api.coinlore.net/api/global/
📋
响应
// 点击发送后，响应会显示在这里
API 端点文档
全局数据
GET
https://api.coinlore.net/api/global/
Information about the crypto market

请求示例
GET
https://api.coinlore.net/api/global/
响应示例
JSON
复制
[
  {
    "coins_count": 14832,
    "active_markets": 43120,
    "total_mcap": 2451835872033.12,
    "total_volume": 89342519012.45,
    "btc_d": "52.31",
    "eth_d": "14.62",
    "mcap_change": "1.24",
    "volume_change": "-8.33",
    "avg_change_percent": "0.87",
    "volume_ath": 344187126292427800,
    "mcap_ath": 8237181118976.519
  }
]
响应字段
字段	类型	说明
coins_count	integer	CoinLore 上可用币种的总数。
active_markets	integer	CoinLore 跟踪的交易所交易对（市场）总数。
total_mcap	number	加密市场总市值：所有币种 USD 市值之和。
total_volume	number	所有币种的 24 小时总交易量（USD）。
btc_d	string	Bitcoin 市值占比（%）。
eth_d	string	Ethereum 市值占比（%）。
mcap_change	string	过去 24 小时总市值变化（%）。
volume_change	string	过去 24 小时总交易量变化（%）。
avg_change_percent	string	所有币种的平均价格变化（%）。
volume_ath	number	总交易量历史最高值。
mcap_ath	number	总市值历史最高值。
cURL
Python
JavaScript
PHP
复制
curl "https://api.coinlore.net/api/global/"
所有资产（轻量列表）
GET
https://api.coinlore.net/api/assets/
返回 CoinLore 上所有币种的轻量列表：仅包含 id、symbol、name、nameid 和 rank。可用于查询表、自动补全或币种选择器，而无需重分页。

请求示例
GET
https://api.coinlore.net/api/assets/
 不需要参数。完整资产列表会在一次响应中返回。要获取单个币种的实时价格，请将其 id 传给 /api/ticker/。

响应示例
JSON
复制
[
  { "id": "90",   "symbol": "BTC",  "name": "Bitcoin",  "nameid": "bitcoin",  "rank": 1 },
  { "id": "80",   "symbol": "ETH",  "name": "Ethereum", "nameid": "ethereum", "rank": 2 },
  { "id": "58",   "symbol": "XRP",  "name": "XRP",      "nameid": "xrp",      "rank": 3 },
  { "id": "2", "symbol": "DOGE", "name": "Dogecoin", "nameid": "dogecoin", "rank": 8 }
]
响应字段
字段	类型	说明
id	string	唯一的 CoinLore 币种 ID。可用于 /api/ticker/、/api/coin/markets/ 和 /api/coin/social_stats/。
symbol	string	Ticker 符号（例如 BTC, ETH）。
name	string	币种全名。
nameid	string	用于 CoinLore 页面路径的 URL slug（例如 bitcoin）。
rank	integer	当前市值排名。
cURL
Python
JavaScript
PHP
复制
curl "https://api.coinlore.net/api/assets/"
Tickers (All coins)
GET
https://api.coinlore.net/api/tickers/
Get data for all coins. The maximum result is 100 coins per request. You should use start and limit

查询参数
参数	类型	默认值	说明
start	integer	0	Offset：要返回的第一个币种索引（从 0 开始，按市值排序）。
limit	integer	100	返回的币种数量。每次请求最多 100 个。
请求示例
GET
https://api.coinlore.net/api/tickers/
排名 #1-100 的币种
GET
https://api.coinlore.net/api/tickers/?start=100&limit=100
排名 #101-200 的币种
GET
https://api.coinlore.net/api/tickers/?start=200&limit=100
排名 #201-300 的币种
 使用响应中的 info.coins_num 获取币种总数，然后通过 start += 100 循环直到全部获取。

响应示例
JSON
复制
{
  "data": [
    {
      "id": "90",
      "symbol": "BTC",
      "name": "Bitcoin",
      "nameid": "bitcoin",
      "rank": 1,
      "price_usd": "6456.52",
      "percent_change_24h": "-1.47",
      "percent_change_1h": "0.05",
      "percent_change_7d": "-1.07",
      "price_btc": "1.00",
      "market_cap_usd": "111586042785.56",
      "volume24": 3997655362.9586277,
      "volume24a": 3657294860.710187,
      "csupply": "17282687.00",
      "tsupply": "17282687",
      "msupply": "21000000"
    }
  ],
  "info": {
    "coins_num": 14832,
    "time": 1538560355
  }
}
响应字段
字段	类型	说明
data[].id	string	该币种的唯一 CoinLore ID。可在 /api/ticker/ 中使用。
data[].symbol	string	Ticker 符号（例如 BTC, ETH）。
data[].name	string	币种全名。
data[].nameid	string	URL slug（例如 bitcoin）。
data[].rank	integer	市值排名。
data[].price_usd	string	当前 USD 价格。
data[].percent_change_1h	string	过去 1 小时价格变化百分比。
data[].percent_change_24h	string	过去 24 小时价格变化百分比。
data[].percent_change_7d	string	过去 7 天价格变化百分比。
data[].price_btc	string	以 BTC 计价的价格。
data[].market_cap_usd	string	市值（USD）。
data[].volume24	number	24 小时交易量（USD）。
data[].volume24a	number	以币种原生单位表示的 24 小时交易量。
data[].csupply	string	流通供应量。
data[].tsupply	string	总供应量。
data[].msupply	string	最大供应量（若无限或未知则为 ""）。
info.coins_num	integer	可用币种总数。与 start 配合使用可分页遍历所有币种。
info.time	integer	此响应生成时的 Unix 时间戳。
cURL
Python
JavaScript
PHP
复制
curl "https://api.coinlore.net/api/tickers/?start=0&limit=100"
Movers
GET
https://api.coinlore.net/api/movers/
返回所选时间窗口内前 20 名上涨币和前 20 名下跌币。仅包含 24 小时成交量至少为 $50,000 的币种。默认窗口为 24h；其他窗口请使用 ?sort=1h 或 ?sort=7d。

查询参数
参数	类型	必填	说明
sort	string	No	排名时间窗口。可接受的值：24h（默认）、1h、7d。
请求示例
GET
https://api.coinlore.net/api/movers/
24h movers（默认）
GET
https://api.coinlore.net/api/movers/?sort=1h
1h movers
GET
https://api.coinlore.net/api/movers/?sort=7d
7d movers
响应示例
JSON
复制
{
  "data": {
    "winners": [
      {
        "id": "45080",
        "symbol": "BLY",
        "name": "Blocery",
        "nameid": "blocery",
        "rank": 1072,
        "price_usd": "0.002352",
        "percent_change_24h": "430.09",
        "percent_change_1h": "26.13",
        "percent_change_7d": "115.77",
        "price_btc": "3.54E-8",
        "market_cap_usd": "2293341.40",
        "volume24": 55022290.69,
        "volume24a": 854462.17,
        "csupply": "974999995.64",
        "tsupply": "1000000000",
        "msupply": "1000000000"
      }
      // ... 19 more winners
    ],
    "losers": [
      {
        "id": "1276",
        "symbol": "BLZ",
        "name": "Bluzelle",
        "nameid": "bluzelle",
        "rank": 862,
        "price_usd": "0.010176",
        "percent_change_24h": "-82.07",
        "percent_change_1h": "0.01",
        "percent_change_7d": "-82.07",
        "price_btc": "1.53E-7",
        "market_cap_usd": "4790084.31",
        "volume24": 353554.96,
        "volume24a": 2186794.90,
        "csupply": "470730576.78",
        "tsupply": "500000000",
        "msupply": null
      }
      // ... 19 more losers
    ]
  }
}
响应字段
data.winners[] 和 data.losers[] 中的每个币种对象都与 /api/tickers/ 项目具有相同结构。关键字段：

字段	类型	说明
data.winners	array	所选时间窗口内最多 20 个涨幅最大的币种。
data.losers	array	所选时间窗口内最多 20 个跌幅最大的币种。
id	string	CoinLore 币种 ID。
symbol	string	Ticker 符号。
name	string	币种名称。
rank	integer	当前市值排名。
price_usd	string|null	当前 USD 价格。若不可用则为 null。
percent_change_1h	string	过去 1 小时价格变化百分比。
percent_change_24h	string	过去 24 小时价格变化百分比。
percent_change_7d	string	过去 7 天价格变化百分比。
market_cap_usd	string|null	USD 市值。若流通供应未知则为 null。
volume24	number	24 小时交易量（USD，当前窗口）。
volume24a	number	24 小时交易量（USD，前一窗口）。
csupply	string|null	流通供应量。若未知则为 null。
tsupply	string	总供应量。
msupply	string|null	最大供应量。若无限或未知则为 null。
Ticker (Specific Coin)
GET
https://api.coinlore.net/api/ticker/
To get information for a specific coin, you should pass coin id (You should use the id from the tickers endpoint)

查询参数
参数	类型	必填	说明
id	string	Yes	CoinLore 币种 ID。你可以传入多个以逗号分隔的 ID（例如 90,80,58）。
请求示例
GET
https://api.coinlore.net/api/ticker/?id=90
Bitcoin (BTC)
GET
https://api.coinlore.net/api/ticker/?id=80
Ethereum (ETH)
GET
https://api.coinlore.net/api/ticker/?id=90,80
一次获取多个币种
响应示例
JSON
复制
[
  {
    "id": "90",
    "symbol": "BTC",
    "name": "Bitcoin",
    "nameid": "bitcoin",
    "rank": 1,
    "price_usd": "6465.26",
    "percent_change_24h": "-1.27",
    "percent_change_1h": "0.19",
    "percent_change_7d": "-0.93",
    "market_cap_usd": "111737012373.28",
    "volume24": "3982512765.23",
    "volume24_native": "615986.77",
    "csupply": "17282687.00",
    "price_btc": "1.00",
    "tsupply": "17282687",
    "msupply": "21000000"
  }
]
响应字段
字段	类型	说明
id	string	唯一的 CoinLore 币种 ID。
symbol	string	Ticker 符号（例如 BTC）。
name	string	币种全名。
nameid	string	URL slug（例如 bitcoin）。
rank	integer	市值排名。
price_usd	string	当前 USD 价格。
percent_change_1h	string	过去 1 小时价格变化百分比。
percent_change_24h	string	过去 24 小时价格变化百分比。
percent_change_7d	string	过去 7 天价格变化百分比。
price_btc	string	以 BTC 计价的价格。
market_cap_usd	string	USD 市值。
volume24	string	24 小时交易量（USD）。
volume24_native	string	以币种原生单位表示的 24 小时交易量。
csupply	string	流通供应量。
tsupply	string	总供应量。
msupply	string	最大供应量（若无限或未知则为 ""）。
cURL
Python
JavaScript
PHP
复制
import requests

# Single or multiple IDs (comma-separated)
r = requests.get("https://api.coinlore.net/api/ticker/",
                 params={"id": "90,80"})
for coin in r.json():
    print(coin["name"], "$" + coin["price_usd"])
币种信息
GET
https://api.coinlore.net/api/coin/info/
返回单个币种的静态元数据：logo URL、历史最高价、供应量数据、上线日期、website、Twitter、block explorer、platform chain 以及首次记录价格日期。不包含实时价格；如需实时价格，请结合 /api/ticker/ 使用。

查询参数
参数	类型	必填	说明
id	string	Yes	CoinLore 币种 ID。可通过 /api/assets/ 或 /api/tickers/ 获取 ID。
请求示例
GET
https://api.coinlore.net/api/coin/info/?id=90
Bitcoin
GET
https://api.coinlore.net/api/coin/info/?id=80
Ethereum
响应示例
JSON
复制
[{
  "id": "90",
  "symbol": "BTC",
  "name": "Bitcoin",
  "nameid": "bitcoin",
  "website": "https://bitcoin.org",
  "twitter": "https://twitter.com/bitcoin",
  "explorer": "https://blockchair.com/bitcoin",
  "logo": "https://c2.coinlore.com/img/25x25/bitcoin.png",
  "rank": 1,
  "ath": 126020.77,
  "ath_date": "2025-10-06",
  "csupply": "19970852",
  "tsupply": "19970852",
  "msupply": "21000000",
  "startdate": "2009-01-03",
  "platform": null,
  "first_price": 134.3975,
  "first_price_date": "2013-04-28T08:15:17Z"
}]
响应字段
字段	类型	说明
id	string	唯一的 CoinLore 币种 ID。
symbol	string	Ticker 符号（例如 BTC）。
name	string	币种全名。
nameid	string	URL slug（例如 bitcoin）。
website	string|null	项目官方网站 URL。
twitter	string|null	官方 Twitter/X 主页 URL。
explorer	string|null	该币种的区块浏览器 URL。
logo	string	25×25 px logo 图片 URL。
rank	integer	当前市值排名。
ath	number	历史最高价（USD）。
ath_date	string	达到 ATH 的日期（YYYY-MM-DD）。
csupply	string	流通供应量。
tsupply	string	总供应量。
msupply	string	最大供应量。若无限或未知则为 null。
startdate	string|null	项目/链上线日期（YYYY-MM-DD）。
platform	string|null	Token 所在的宿主链（例如 ethereum）。原生币返回 null。
first_price	number	首次记录的价格（USD）。
first_price_date	string	首次记录价格的 ISO 8601 时间戳。
cURL
Python
JavaScript
PHP
复制
curl "https://api.coinlore.net/api/coin/info/?id=90"
OHLCV 历史
GET
https://api.coinlore.net/api/coin/ohlcv/
返回单个币种 365 天的日 OHLCV 历史。每一行包含 timestamp、open、high、low、close 和 volume，并以日历日期为键。

查询参数
参数	类型	必填	说明
coin	integer	Yes	CoinLore 币种 ID。例如：1、90 或 CoinLore 上任意有效币种 ID。
请求示例
GET
https://api.coinlore.net/api/coin/ohlcv/?coin=1
返回 365 根日线蜡烛
 此 endpoint 使用 coin 查询参数，而不是 id。响应是按日期为键的对象，而不是分页数组。

响应示例
JSON
复制
{
  "2026-04-08": [1744070400, 69321.14, 70102.50, 68844.80, 69811.27, 1823456789.42],
  "2026-04-07": [1743984000, 68792.65, 69510.20, 68122.19, 69321.14, 1712345678.11],
  "2026-04-06": [1743897600, 68155.48, 68943.09, 67720.44, 68792.65, 1649876543.77]
}
响应格式
位置	类型	说明
[0]	integer	蜡烛图的 Unix 时间戳。
[1]	number	开盘价（USD）。
[2]	number	最高价（USD）。
[3]	number	最低价（USD）。
[4]	number	收盘价（USD）。
[5]	number	当日成交量。
cURL
Python
JavaScript
PHP
复制
curl "https://api.coinlore.net/api/coin/ohlcv/?coin=90"
Get Markets For Coin
GET
https://api.coinlore.net/api/coin/markets/
Returns first 50 markets for a specific coin

查询参数
参数	类型	必填	说明
id	string	Yes	CoinLore 币种 ID（例如 Bitcoin 为 90）。可通过 /api/ticker/ 查询 ID。
Example Requests
GET
https://api.coinlore.net/api/coin/markets/?id=90
Bitcoin 市场
GET
https://api.coinlore.net/api/coin/markets/?id=80
Ethereum 市场
Response Sample
JSON
Copy
[
  {
    "name": "Binance",
    "base": "BTC",
    "quote": "USDT",
    "price": 43042.31,
    "price_usd": 43042.31,
    "volume": 18102.076,
    "volume_usd": 779155177.596,
    "time": 1706972454
  },
  {
    "name": "Coinbase",
    "base": "BTC",
    "quote": "USD",
    "price": 43038.12,
    "price_usd": 43038.12,
    "volume": 9254.413,
    "volume_usd": 398312047.82,
    "time": 1706972431
  }
]
响应字段
字段	类型	说明
name	string	交易所名称。
base	string	交易对的基础加密货币。
quote	string	交易对的计价货币。
price	number	按计价货币表示的价格。
price_usd	number	转换为 USD 的价格。
volume	number	按基础币单位表示的 24 小时交易量。
volume_usd	number	24 小时交易量（USD）。
time	integer	最近一次价格更新的 Unix 时间戳。
cURL
Python
JavaScript
PHP
复制
curl "https://api.coinlore.net/api/coin/markets/?id=90"
All Exchanges
GET
https://api.coinlore.net/api/exchanges/
Get all exchanges

请求示例
GET
https://api.coinlore.net/api/exchanges/
 响应是一个按交易所 ID 索引的对象。可将每个 id 与 /api/exchange/ 一起使用，以获取完整交易对数据。

响应示例
JSON
复制
{
  "5": {
    "id": "5",
    "name": "Binance",
    "name_id": "binance",
    "volume_usd": 425535383.29,
    "active_pairs": 852,
    "url": "https://www.binance.com",
    "country": "Japan"
  },
  "9": {
    "id": "9",
    "name": "Bitfinex",
    "name_id": "bitfinex2",
    "volume_usd": 444695.18,
    "active_pairs": 159,
    "url": "https://www.bitfinex.com",
    "country": "Hong Kong"
  }
}
响应字段
字段	类型	说明
id	string	唯一的 CoinLore 交易所 ID。可用于 /api/exchange/。
name	string	交易所显示名称。
name_id	string	交易所的 URL slug。
volume_usd	number	24 小时总交易量（USD）。
active_pairs	integer	该交易所的活跃交易对数量。
url	string	交易所网站 URL。
country	string	交易所注册或所在国家。
cURL
Python
JavaScript
PHP
复制
curl "https://api.coinlore.net/api/exchanges/"
Fetch exchange data
GET
https://api.coinlore.net/api/exchange/
Get specific exchange by ID (Returns Top 100 Pairs)

查询参数
参数	类型	必填	说明
id	string	Yes	CoinLore 交易所 ID。请从 /api/exchanges/ 获取 ID。
请求示例
GET
https://api.coinlore.net/api/exchange/?id=5
Binance
GET
https://api.coinlore.net/api/exchange/?id=9
Bitfinex
响应示例
JSON
复制
{
  "0": {
    "name": "Binance",
    "date_live": "2017-07-01",
    "url": "https://www.binance.com"
  },
  "pairs": [
    {
      "base": "BNB",
      "quote": "USDT",
      "volume": 91368012.29,
      "price": 17.1944,
      "price_usd": 17.1944,
      "time": 1553469901
    },
    {
      "base": "BTC",
      "quote": "USDT",
      "volume": 68102151.93,
      "price": 3988.61,
      "price_usd": 3988.61,
      "time": 1553469901
    }
  ]
}
响应字段
字段	类型	说明
0.name	string	交易所显示名称。
0.date_live	string	交易所上线日期（YYYY-MM-DD）。
0.url	string	交易所网站 URL。
pairs[].base	string	交易对的基础加密货币。
pairs[].quote	string	交易对的计价货币。
pairs[].volume	number	按基础币单位表示的 24 小时交易量。
pairs[].price	number	按计价货币表示的价格。
pairs[].price_usd	number	转换为 USD 的价格。
pairs[].time	integer	该交易对最近更新的 Unix 时间戳。
cURL
Python
JavaScript
PHP
复制
curl "https://api.coinlore.net/api/exchange/?id=5"
Social Stats
GET
https://api.coinlore.net/api/coin/social_stats/
Get social stats for coin

Query Parameters
参数	类型	必填	说明
id	string	Yes	CoinLore 币种 ID（例如 Bitcoin 为 90）。
请求示例
GET
https://api.coinlore.net/api/coin/social_stats/?id=90
Bitcoin 社交统计
GET
https://api.coinlore.net/api/coin/social_stats/?id=80
Ethereum 社交统计
响应示例
JSON
复制
{
  "reddit": {
    "avg_active_users": 4409.25,
    "subscribers": 373581
  },
  "twitter": {
    "followers_count": 414355,
    "status_count": 1919
  }
}
响应字段
字段	类型	说明
reddit.avg_active_users	number	该币种 subreddit 的平均活跃 Reddit 用户数。
reddit.subscribers	integer	subreddit 总订阅数。
twitter.followers_count	integer	项目官方 Twitter/X 账号的关注者数量。
twitter.status_count	integer	官方账号的总推文/发帖数。
cURL
Python
JavaScript
PHP
复制
curl "https://api.coinlore.net/api/coin/social_stats/?id=90"
SDK

Python

NodeJS

PHP
CoinLore API 是免费的吗？
是的，CoinLore 的加密货币 API 100% 免费。无需注册或 API key，并为 12,000+ 个币种提供实时数据。

CoinLore API 提供哪些数据？
该 API 提供实时价格、交易量、市值、供应量、历史数据以及数千种加密货币（包括 Bitcoin 和 Ethereum）的详细指标。

访问 CoinLore API 需要 API key 吗？
不需要。CoinLore 的公开 API 对所有人开放，不需要任何认证。

CoinLore 的免费 API 有速率限制吗？
虽然没有严格的速率限制，但我们建议适度使用，以确保公平访问。

关于
CoinLore 提供基于自身算法计算的加密货币价格和市场数据。价格、市值、交易量、历史价格、图表等指标均通过聚合多个交易平台的数据并进行内部处理得出。我们还结合区块链数据、API、小部件及其他分析工具，为用户提供全面的市场参考信息。同时，我们会从多个可靠来源收集补充信息，以确保重要事件和关键数据得到覆盖。

⚠交易的风险很大。如果您想要交易加密货币，请咨询专业的财务顾问。

联系
 / 电邮: contact@coinlore.com

Info
Crypto API
Widgets
隐私政策
关于我们
X(Twitter)
Facebook
Get it on Apple Store

Get it on Google Play

Get it on Microsoft Store
⚠ 免责声明： 本网站提供的信息仅供一般性信息和研究用途，不构成任何形式的财务、投资、法律或其他专业建议。网站中的任何内容均不应被视为推荐或要约。加密货币市场具有高度波动性并存在风险。用户在做出任何财务决策之前，应自行进行研究，并在必要时寻求独立的专业意见。数字资产的法律地位可能因司法管辖区而异。

© 2026 CoinLore, LLC
