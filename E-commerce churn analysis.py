import sqlite3, random, re
random.seed(1)
c = sqlite3.connect('t.db')
c.execute("""CREATE TABLE ecommerce_churn(
    CustomerID INT, Churn INT, Tenure REAL, PreferredLoginDevice TEXT,
    CityTier INT, WarehouseToHome REAL, PreferredPaymentMode TEXT, Gender TEXT,
    HourSpendOnApp REAL, NumberOfDeviceRegistered INT, PreferedOrderCat TEXT,
    SatisfactionScore INT, MaritalStatus TEXT, NumberOfAddress INT, Complain INT,
    OrderAmountHikeFromlastYear REAL, CouponUsed REAL, OrderCount REAL,
    DaySinceLastOrder REAL, CashbackAmount REAL)""")

rows = []
for i in range(3000):
    comp = random.random() < .28
    ten = random.choice([None] + list(range(0, 40)))
    sat = random.randint(1, 5)
    p = .1 + .2*comp + .05*(sat <= 2) + (.15 if ten is not None and ten <= 3 else 0)
    rows.append((i, int(random.random() < p), ten, 'Phone', random.randint(1, 3), 10,
                 random.choice(['CC', 'COD', 'UPI', 'Debit Card']), 'M', 3, 3,
                 random.choice(['Laptop', 'Mobile']), sat, 'Single', 3, int(comp), 15,
                 random.choice([None, 0, 1, 2, 4, 7]),
                 random.choice([None, 1, 2, 5, 10]),
                 random.choice([None, 0, 3, 9, 15]),
                 random.uniform(100, 300)))
c.executemany("INSERT INTO ecommerce_churn VALUES(%s)" % ",".join("?"*20), rows)

sql = open('/mnt/user-data/outputs/ecommerce_churn_analysis.sql').read()
try:
    c.executescript(sql)
    print("script ran OK")
except Exception as e:
    print("ERR", e)

n = 0
for s in sql.split(";"):
    s2 = re.sub(r"(?s)/\*.*?\*/", "", s)
    s2 = re.sub(r"--.*", "", s2).strip()
    if s2.upper().startswith(("SELECT", "WITH")):
        c.execute(s2).fetchall()
        n += 1
print(n, "queries executed")
