-- CustomerService 初始业务样例数据
-- 包含 6 条 FAQ、2 个已结束的样例会话和 4 条消息,用于本地验证和知识抽取。
-- 在 001_schema.sql 之后执行;仅供新数据库初始化。

SET NAMES utf8mb4;

-- FAQ:查询现有行数,替换同题样例,核验结果。
SELECT COUNT(*) AS before_rows FROM faq;

DELETE FROM faq
WHERE question IN ('退货政策', '如何申请退款', '换货流程', '发货时效', '运费怎么算', '发票如何开具');

INSERT INTO faq (question, answer, category) VALUES
  ('退货政策',   '支持 7 天无理由退货,商品需保持完好、不影响二次销售,具体以平台售后规则为准。', '售后'),
  ('如何申请退款', '在「我的订单」找到对应订单点击「申请退款」,按提示提交,审核通过后原路退回。',   '售后'),
  ('换货流程',   '收到商品 7 天内可申请换货,联系客服登记后将商品寄回,平台核验无误后补发新品。',   '售后'),
  ('发货时效',   '现货商品付款后 48 小时内发货,预售商品以商品详情页标注的发货时间为准。',       '物流'),
  ('运费怎么算', '单笔订单满 99 元包邮,未满收取 10 元运费,偏远地区运费另计。',                 '物流'),
  ('发票如何开具', '在「我的订单」-「申请开票」提交抬头与税号,电子发票将于 3 个工作日内发送至邮箱。', '账务');

SELECT COUNT(*) AS after_rows FROM faq;

-- BEGIN HISTORY SEED
-- 历史会话:清理同名样例后写入,核验会话和消息数量。
SELECT COUNT(*) AS before_conv FROM conversations WHERE user_id LIKE 'seed-%';

DELETE FROM messages WHERE conversation_id IN (SELECT id FROM conversations WHERE user_id LIKE 'seed-%');
DELETE FROM conversations WHERE user_id LIKE 'seed-%';

INSERT INTO conversations (user_id, status) VALUES ('seed-u1', '已结束'), ('seed-u2', '已结束');
SET @c1 = (SELECT id FROM conversations WHERE user_id = 'seed-u1' ORDER BY id DESC LIMIT 1);
SET @c2 = (SELECT id FROM conversations WHERE user_id = 'seed-u2' ORDER BY id DESC LIMIT 1);

INSERT INTO messages (conversation_id, role, content) VALUES
  (@c1, 'user',      '你们发货一般多久啊'),
  (@c1, 'assistant', '现货商品付款后 48 小时内发货,预售以商品详情页标注时间为准。'),
  (@c2, 'user',      '满多少包邮'),
  (@c2, 'assistant', '单笔订单满 99 元包邮,未满收取 10 元运费,偏远地区另计。');

SELECT COUNT(*) AS after_conv FROM conversations WHERE user_id LIKE 'seed-%';
SELECT COUNT(*) AS after_msg FROM messages WHERE conversation_id IN (SELECT id FROM conversations WHERE user_id LIKE 'seed-%');
