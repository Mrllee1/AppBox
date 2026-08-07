"use client";

import "@ant-design/v5-patch-for-react-19";
import { useEffect, useMemo, useState } from "react";
import {
  App,
  Button,
  ConfigProvider,
  Form,
  Input,
  Modal,
  Spin,
  Select,
  Space,
  Switch,
  Table,
  Tag,
  Typography
} from "antd";
import {
  ApiOutlined,
  AppstoreOutlined,
  BarChartOutlined,
  LinkOutlined,
  LogoutOutlined,
  PlusOutlined,
  ReloadOutlined
} from "@ant-design/icons";
import type { ColumnsType } from "antd/es/table";
import { AdminApp, AdminSummary, AdminUser, api } from "../lib/api";

const { Text } = Typography;

export function AdminDashboard() {
  return (
    <ConfigProvider
      theme={{
        token: {
          borderRadius: 14,
          colorPrimary: "#4f46e5",
          fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', sans-serif"
        },
        components: {
          Button: { controlHeight: 38 },
          Table: { headerBg: "rgba(248,250,252,0.84)", rowHoverBg: "rgba(79,70,229,0.04)" }
        }
      }}
    >
      <App>
        <DashboardContent />
      </App>
    </ConfigProvider>
  );
}

function DashboardContent() {
  const { message } = App.useApp();
  const [authChecking, setAuthChecking] = useState(true);
  const [authLoading, setAuthLoading] = useState(false);
  const [user, setUser] = useState<AdminUser | null>(null);
  const [summary, setSummary] = useState<AdminSummary | null>(null);
  const [apps, setApps] = useState<AdminApp[]>([]);
  const [mappings, setMappings] = useState<unknown[]>([]);
  const [categories, setCategories] = useState<Array<{ id: string; name: string }>>([]);
  const [groups, setGroups] = useState<Array<{ id: string; name: string; categoryId: string }>>([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [deeplinkResult, setDeeplinkResult] = useState<Record<string, unknown> | null>(null);
  const [form] = Form.useForm();
  const [deeplinkForm] = Form.useForm();
  const [loginForm] = Form.useForm();

  async function bootstrapAuth() {
    const token = window.localStorage.getItem("appbox_admin_token") || "";
    if (!token) {
      setAuthChecking(false);
      return;
    }
    api.setToken(token);
    try {
      const result = await api.me();
      setUser(result.user);
      await load();
    } catch {
      api.setToken("");
      window.localStorage.removeItem("appbox_admin_token");
    } finally {
      setAuthChecking(false);
    }
  }

  async function login(values: { password: string; username: string }) {
    setAuthLoading(true);
    try {
      const result = await api.login(values);
      api.setToken(result.token);
      window.localStorage.setItem("appbox_admin_token", result.token);
      setUser(result.user);
      message.success("登录成功");
      await load();
    } catch (error) {
      message.error(error instanceof Error ? error.message : "登录失败");
    } finally {
      setAuthLoading(false);
    }
  }

  function logout() {
    api.setToken("");
    window.localStorage.removeItem("appbox_admin_token");
    setUser(null);
    setSummary(null);
    setApps([]);
    setMappings([]);
    setCategories([]);
    setGroups([]);
    loginForm.resetFields();
  }

  async function load() {
    if (!user && !window.localStorage.getItem("appbox_admin_token")) return;
    setLoading(true);
    try {
      const [summaryRes, appsRes, mappingsRes, categoriesRes, groupsRes] = await Promise.all([
        api.summary(),
        api.apps(),
        api.mappings(),
        api.categories(),
        api.groups()
      ]);
      setSummary(summaryRes);
      setApps(appsRes.data);
      setMappings(mappingsRes.data);
      setCategories(categoriesRes.data);
      setGroups(groupsRes.data);
    } catch (error) {
      if (error instanceof Error && error.message.startsWith("401 ")) {
        logout();
        message.error("登录已过期，请重新登录");
        return;
      }
      message.error(error instanceof Error ? error.message : "加载失败");
    } finally {
      setLoading(false);
    }
  }

  const columns: ColumnsType<AdminApp> = useMemo(
    () => [
      {
        title: "App",
        dataIndex: "name",
        render: (_, record) => (
          <Space>
            <img
              src={record.iconUrl}
              alt=""
              width={34}
              height={34}
              style={{ borderRadius: 9, objectFit: "cover", background: "#eef2ff" }}
            />
            <div>
              <div style={{ fontWeight: 700 }}>{record.name}</div>
              <Text type="secondary" style={{ fontSize: 12 }}>
                {record.id}
              </Text>
            </div>
          </Space>
        )
      },
      {
        title: "类型",
        dataIndex: "type",
        width: 86,
        render: (type: string) => <Tag color={type === "ipa" ? "blue" : "purple"}>{type.toUpperCase()}</Tag>
      },
      {
        title: "版本",
        dataIndex: "version",
        width: 90
      },
      {
        title: "状态",
        dataIndex: "enabled",
        width: 90,
        render: (enabled: boolean) => <Tag color={enabled ? "green" : "default"}>{enabled ? "上架" : "下架"}</Tag>
      },
      {
        title: "排序",
        dataIndex: "sort",
        width: 80
      },
      {
        title: "入口",
        width: 240,
        render: (_, record) => (
          <Text ellipsis style={{ maxWidth: 220 }}>
            {record.type === "ipa" ? record.downloadUrl : record.entryUrl}
          </Text>
        )
      }
    ],
    []
  );

  useEffect(() => {
    void bootstrapAuth();
  }, []);

  if (authChecking) {
    return (
      <main className="login-shell">
        <div className="login-card glass">
          <Spin />
        </div>
      </main>
    );
  }

  if (!user) {
    return (
      <main className="login-shell">
        <section className="login-card glass">
          <div className="login-brand">
            <div className="brand-mark">盒</div>
            <div>
              <h1>天涯盒子</h1>
              <p>管理后台</p>
            </div>
          </div>
          <Form
            form={loginForm}
            layout="vertical"
            initialValues={{ username: "admin" }}
            onFinish={login}
            requiredMark={false}
          >
            <Form.Item name="username" label="账号" rules={[{ required: true, message: "请输入账号" }]}>
              <Input autoComplete="username" size="large" />
            </Form.Item>
            <Form.Item name="password" label="密码" rules={[{ required: true, message: "请输入密码" }]}>
              <Input.Password autoComplete="current-password" size="large" />
            </Form.Item>
            <Button type="primary" htmlType="submit" block size="large" loading={authLoading}>
              登录
            </Button>
          </Form>
        </section>
      </main>
    );
  }

  async function submitApp(values: Partial<AdminApp>) {
    try {
      await api.createApp(values);
      message.success("App 已创建");
      setModalOpen(false);
      form.resetFields();
      await load();
    } catch (error) {
      message.error(error instanceof Error ? error.message : "创建失败");
    }
  }

  async function resolveDeeplink(values: Record<string, string>) {
    try {
      const result = await api.resolveDeeplink(values);
      setDeeplinkResult(result);
      message.success("解析成功");
    } catch (error) {
      setDeeplinkResult(null);
      message.error(error instanceof Error ? error.message : "解析失败");
    }
  }

  async function sendTestEvent() {
    try {
      await api.trackTestEvent();
      message.success("测试事件已上报");
      await load();
    } catch (error) {
      message.error(error instanceof Error ? error.message : "上报失败");
    }
  }

  return (
    <main className="shell">
      <section className="hero">
        <div>
          <h1>天涯盒子管理后台</h1>
          <p>管理 App、外部映射、深链接解析和统计事件。API: {api.baseUrl}</p>
        </div>
        <Space>
          <Button icon={<ReloadOutlined />} onClick={load}>
            刷新
          </Button>
          <Button type="primary" icon={<PlusOutlined />} onClick={() => setModalOpen(true)}>
            新增 App
          </Button>
          <Button icon={<LogoutOutlined />} onClick={logout}>
            退出
          </Button>
        </Space>
      </section>

      <section className="metric-grid">
        <Metric icon={<AppstoreOutlined />} label="上架 App" value={summary?.enabled_apps ?? 0} />
        <Metric icon={<ApiOutlined />} label="IPA / H5" value={`${summary?.ipa_apps ?? 0}/${summary?.web_apps ?? 0}`} />
        <Metric icon={<LinkOutlined />} label="外部映射" value={summary?.mappings ?? mappings.length} />
        <Metric icon={<BarChartOutlined />} label="今日事件" value={summary?.events?.today_events ?? 0} />
      </section>

      <section className="content-grid">
        <div className="panel glass">
          <div className="panel-title">
            <h2>App 列表</h2>
            <Tag color="blue">{apps.length} 个</Tag>
          </div>
          <Table
            rowKey="id"
            loading={loading}
            columns={columns}
            dataSource={apps}
            pagination={{ pageSize: 8, showSizeChanger: false }}
          />
        </div>

        <div className="panel glass">
          <div className="panel-title">
            <h2>深链接测试</h2>
            <Tag>Resolve</Tag>
          </div>
          <Form
            form={deeplinkForm}
            layout="vertical"
            initialValues={{ app_id: "3101", p_channel: "wc2dc", plat: "3" }}
            onFinish={resolveDeeplink}
          >
            <Form.Item name="app_id" label="外部 App ID" rules={[{ required: true }]}>
              <Input placeholder="3101" />
            </Form.Item>
            <Form.Item name="p_channel" label="渠道">
              <Input placeholder="wc2dc" />
            </Form.Item>
            <Form.Item name="plat" label="平台">
              <Select
                options={[
                  { value: "3", label: "iOS" },
                  { value: "2", label: "Android" },
                  { value: "all", label: "All" }
                ]}
              />
            </Form.Item>
            <Space>
              <Button type="primary" htmlType="submit">
                解析目标 App
              </Button>
              <Button onClick={sendTestEvent}>上报测试事件</Button>
            </Space>
          </Form>

          {deeplinkResult ? (
            <pre
              style={{
                marginTop: 16,
                padding: 14,
                borderRadius: 14,
                background: "rgba(15,23,42,0.04)",
                overflow: "auto"
              }}
            >
              {JSON.stringify(deeplinkResult, null, 2)}
            </pre>
          ) : null}
        </div>
      </section>

      <Modal
        title="新增 App"
        open={modalOpen}
        onCancel={() => setModalOpen(false)}
        onOk={() => form.submit()}
        destroyOnHidden
      >
        <Form
          form={form}
          layout="vertical"
          initialValues={{
            type: "web",
            categoryId: categories[0]?.id || "tools",
            groupId: groups[0]?.id || "wallet",
            sort: 100,
            enabled: true,
            recommended: false
          }}
          onFinish={submitApp}
        >
          <Form.Item name="name" label="名称" rules={[{ required: true }]}>
            <Input />
          </Form.Item>
          <Form.Item name="type" label="类型" rules={[{ required: true }]}>
            <Select
              options={[
                { value: "ipa", label: "IPA" },
                { value: "web", label: "H5" }
              ]}
            />
          </Form.Item>
          <Form.Item name="categoryId" label="分类" rules={[{ required: true }]}>
            <Select options={categories.map((item) => ({ value: item.id, label: item.name }))} />
          </Form.Item>
          <Form.Item name="groupId" label="分组" rules={[{ required: true }]}>
            <Select options={groups.map((item) => ({ value: item.id, label: item.name }))} />
          </Form.Item>
          <Form.Item name="iconUrl" label="图标 URL" rules={[{ required: true, type: "url" }]}>
            <Input />
          </Form.Item>
          <Form.Item shouldUpdate noStyle>
            {({ getFieldValue }) =>
              getFieldValue("type") === "ipa" ? (
                <>
                  <Form.Item name="bundleId" label="Bundle ID">
                    <Input />
                  </Form.Item>
                  <Form.Item name="downloadUrl" label="IPA 下载地址" rules={[{ required: true, type: "url" }]}>
                    <Input />
                  </Form.Item>
                </>
              ) : (
                <Form.Item name="entryUrl" label="H5 地址" rules={[{ required: true, type: "url" }]}>
                  <Input />
                </Form.Item>
              )
            }
          </Form.Item>
          <Form.Item name="version" label="版本">
            <Input placeholder="1.0.0" />
          </Form.Item>
          <Form.Item name="enabled" label="上架" valuePropName="checked">
            <Switch />
          </Form.Item>
        </Form>
      </Modal>
    </main>
  );
}

function Metric({ icon, label, value }: { icon: React.ReactNode; label: string; value: React.ReactNode }) {
  return (
    <div className="metric-card glass">
      <Space>
        {icon}
        <span>{label}</span>
      </Space>
      <strong>{value}</strong>
    </div>
  );
}
