"use client";

import "@ant-design/v5-patch-for-react-19";
import { useEffect, useMemo, useState } from "react";
import {
  App,
  Button,
  ConfigProvider,
  Divider,
  Form,
  Input,
  InputNumber,
  Layout,
  Menu,
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
  CloudUploadOutlined,
  LinkOutlined,
  LogoutOutlined,
  PlusOutlined,
  ReloadOutlined,
  SettingOutlined
} from "@ant-design/icons";
import type { ColumnsType } from "antd/es/table";
import { AdminApp, AdminCategory, AdminGroup, AdminMapping, AdminSummary, AdminUser, PlatformConfig, api } from "../lib/api";

const { Text } = Typography;

type AdminSection = "overview" | "apps" | "taxonomy" | "deeplink" | "platform" | "diagnostics";

interface GeneratedDeepLink {
  description: string;
  label: string;
  value: string;
}

const sectionMeta: Record<AdminSection, { description: string; title: string }> = {
  overview: {
    title: "概览",
    description: "核心数据和运行状态总览"
  },
  apps: {
    title: "App 管理",
    description: "维护 IPA 与 H5 应用、图标、版本和上架状态"
  },
  taxonomy: {
    title: "分类配置",
    description: "维护客户端动态读取的分类和分组"
  },
  deeplink: {
    title: "深链接",
    description: "验证外部落地页参数是否能解析到指定 App"
  },
  platform: {
    title: "远程配置",
    description: "配置 API 入口、GitHub 配置源和 Cloudflare R2"
  },
  diagnostics: {
    title: "发布检测",
    description: "测试入口连通性、R2 配置和 GitHub/CDN 发布结果"
  }
};

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
  const { message, modal } = App.useApp();
  const [authChecking, setAuthChecking] = useState(true);
  const [authLoading, setAuthLoading] = useState(false);
  const [user, setUser] = useState<AdminUser | null>(null);
  const [summary, setSummary] = useState<AdminSummary | null>(null);
  const [apps, setApps] = useState<AdminApp[]>([]);
  const [mappings, setMappings] = useState<AdminMapping[]>([]);
  const [categories, setCategories] = useState<AdminCategory[]>([]);
  const [groups, setGroups] = useState<AdminGroup[]>([]);
  const [platformConfig, setPlatformConfig] = useState<PlatformConfig | null>(null);
  const [configCdnUrls, setConfigCdnUrls] = useState<string[]>([]);
  const [configPreview, setConfigPreview] = useState<Record<string, unknown> | null>(null);
  const [entrypointResults, setEntrypointResults] = useState<Array<Record<string, unknown>>>([]);
  const [r2Result, setR2Result] = useState<Record<string, unknown> | null>(null);
  const [platformBusy, setPlatformBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingApp, setEditingApp] = useState<AdminApp | null>(null);
  const [categoryModalOpen, setCategoryModalOpen] = useState(false);
  const [editingCategory, setEditingCategory] = useState<AdminCategory | null>(null);
  const [groupModalOpen, setGroupModalOpen] = useState(false);
  const [editingGroup, setEditingGroup] = useState<AdminGroup | null>(null);
  const [linkModalOpen, setLinkModalOpen] = useState(false);
  const [linkTargetApp, setLinkTargetApp] = useState<AdminApp | null>(null);
  const [generatedLinks, setGeneratedLinks] = useState<GeneratedDeepLink[]>([]);
  const [activeSection, setActiveSection] = useState<AdminSection>("overview");
  const [deeplinkResult, setDeeplinkResult] = useState<Record<string, unknown> | null>(null);
  const [form] = Form.useForm();
  const [categoryForm] = Form.useForm();
  const [groupForm] = Form.useForm();
  const [deeplinkForm] = Form.useForm();
  const [loginForm] = Form.useForm();
  const [platformForm] = Form.useForm<PlatformConfig>();

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
    setPlatformConfig(null);
    setConfigCdnUrls([]);
    setConfigPreview(null);
    setEntrypointResults([]);
    setR2Result(null);
    loginForm.resetFields();
  }

  async function load() {
    if (!user && !window.localStorage.getItem("appbox_admin_token")) return;
    setLoading(true);
    try {
      const [summaryRes, appsRes, mappingsRes, categoriesRes, groupsRes, platformRes] = await Promise.all([
        api.summary(),
        api.apps(),
        api.mappings(),
        api.categories(),
        api.groups(),
        api.platformConfig()
      ]);
      setSummary(summaryRes);
      setApps(appsRes.data);
      setMappings(mappingsRes.data);
      setCategories(categoriesRes.data);
      setGroups(groupsRes.data);
      setPlatformConfig(platformRes.data);
      setConfigCdnUrls(platformRes.cdnUrls);
      platformForm.setFieldsValue(platformFormValues(platformRes.data));
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
        width: 220,
        render: (_, record) => (
          <Space className="app-name-cell" size={10}>
            <img
              src={record.iconUrl}
              alt=""
              width={32}
              height={32}
              style={{ borderRadius: 8, objectFit: "cover", background: "#eef2ff", flex: "0 0 auto" }}
            />
            <div className="app-name-meta">
              <Text strong ellipsis>
                {record.name}
              </Text>
              <Text type="secondary" ellipsis style={{ fontSize: 12 }}>
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
        width: 92,
        render: (version?: string) => version || "-"
      },
      {
        title: "状态",
        dataIndex: "enabled",
        width: 86,
        render: (enabled: boolean) => <Tag color={enabled ? "green" : "default"}>{enabled ? "上架" : "下架"}</Tag>
      },
      {
        title: "排序",
        dataIndex: "sort",
        width: 76
      },
      {
        title: "入口",
        width: 260,
        render: (_, record) => (
          <Text ellipsis style={{ maxWidth: 240 }}>
            {record.type === "ipa" ? record.downloadUrl : record.entryUrl}
          </Text>
        )
      },
      {
        title: "操作",
        width: 230,
        fixed: "right",
        render: (_, record) => (
          <Space className="table-actions" size={4}>
            <Button size="small" type="link" icon={<LinkOutlined />} onClick={() => openLinkModal(record)}>
              生成深链接
            </Button>
            <Button size="small" type="link" onClick={() => openEditApp(record)}>
              编辑
            </Button>
            <Button size="small" type="link" danger disabled={!record.enabled} onClick={() => confirmDeleteApp(record)}>
              删除
            </Button>
          </Space>
        )
      }
    ],
    [mappings, platformConfig]
  );

  const categoryColumns: ColumnsType<AdminCategory> = useMemo(
    () => [
      {
        title: "分类",
        dataIndex: "name",
        width: 220,
        render: (_, record) => (
          <div className="app-name-meta taxonomy-name-meta">
            <Text strong ellipsis>
              {record.name}
            </Text>
            <Text type="secondary" ellipsis style={{ fontSize: 12 }}>
              {record.id}
            </Text>
          </div>
        )
      },
      {
        title: "英文名",
        dataIndex: "englishName",
        width: 160,
        render: (value?: string) => value || "-"
      },
      {
        title: "排序",
        dataIndex: "sort",
        width: 80
      },
      {
        title: "状态",
        dataIndex: "enabled",
        width: 86,
        render: (enabled: boolean) => <Tag color={enabled ? "green" : "default"}>{enabled ? "启用" : "停用"}</Tag>
      },
      {
        title: "操作",
        width: 132,
        fixed: "right",
        render: (_, record) => (
          <Space className="table-actions" size={4}>
            <Button size="small" type="link" onClick={() => openEditCategory(record)}>
              编辑
            </Button>
            <Button size="small" type="link" danger disabled={!record.enabled} onClick={() => confirmDeleteCategory(record)}>
              删除
            </Button>
          </Space>
        )
      }
    ],
    []
  );

  const groupColumns: ColumnsType<AdminGroup> = useMemo(
    () => [
      {
        title: "分组",
        dataIndex: "name",
        width: 220,
        render: (_, record) => (
          <div className="app-name-meta taxonomy-name-meta">
            <Text strong ellipsis>
              {record.name}
            </Text>
            <Text type="secondary" ellipsis style={{ fontSize: 12 }}>
              {record.id}
            </Text>
          </div>
        )
      },
      {
        title: "所属分类",
        dataIndex: "categoryId",
        width: 160,
        render: (categoryId: string) => categories.find((category) => category.id === categoryId)?.name || categoryId
      },
      {
        title: "英文名",
        dataIndex: "englishName",
        width: 150,
        render: (value?: string) => value || "-"
      },
      {
        title: "排序",
        dataIndex: "sort",
        width: 80
      },
      {
        title: "状态",
        dataIndex: "enabled",
        width: 86,
        render: (enabled: boolean) => <Tag color={enabled ? "green" : "default"}>{enabled ? "启用" : "停用"}</Tag>
      },
      {
        title: "操作",
        width: 132,
        fixed: "right",
        render: (_, record) => (
          <Space className="table-actions" size={4}>
            <Button size="small" type="link" onClick={() => openEditGroup(record)}>
              编辑
            </Button>
            <Button size="small" type="link" danger disabled={!record.enabled} onClick={() => confirmDeleteGroup(record)}>
              删除
            </Button>
          </Space>
        )
      }
    ],
    [categories]
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

  function appFormInitialValues() {
    const category = categories.find((item) => item.enabled) ?? categories[0];
    const group = groups.find((item) => item.enabled && item.categoryId === category?.id) ??
      groups.find((item) => item.categoryId === category?.id) ??
      groups[0];
    return {
      type: "web",
      categoryId: category?.id || "",
      groupId: group?.id || "",
      sort: 100,
      enabled: true,
      recommended: false
    };
  }

  function openCreateApp() {
    setEditingApp(null);
    form.resetFields();
    form.setFieldsValue(appFormInitialValues());
    setModalOpen(true);
  }

  function openEditApp(record: AdminApp) {
    setEditingApp(record);
    form.resetFields();
    form.setFieldsValue({
      ...appFormInitialValues(),
      ...record
    });
    setModalOpen(true);
  }

  function closeAppModal() {
    setModalOpen(false);
    setEditingApp(null);
    form.resetFields();
  }

  async function submitApp(values: Partial<AdminApp>) {
    try {
      if (editingApp) {
        await api.updateApp(editingApp.id, normalizeAppPayload(values));
        message.success("App 已更新");
      } else {
        await api.createApp(normalizeAppPayload(values));
        message.success("App 已创建");
      }
      closeAppModal();
      await load();
    } catch (error) {
      message.error(error instanceof Error ? error.message : editingApp ? "更新失败" : "创建失败");
    }
  }

  function confirmDeleteApp(record: AdminApp) {
    modal.confirm({
      title: `删除 ${record.name}`,
      content: "删除后该 App 会下架，不会从数据文件中物理移除。",
      okText: "删除",
      okButtonProps: { danger: true },
      cancelText: "取消",
      onOk: () => deleteApp(record)
    });
  }

  async function deleteApp(record: AdminApp) {
    try {
      await api.deleteApp(record.id);
      message.success("App 已下架");
      await load();
    } catch (error) {
      message.error(error instanceof Error ? error.message : "删除失败");
    }
  }

  function categoryFormInitialValues() {
    return {
      sort: 100,
      enabled: true
    };
  }

  function groupFormInitialValues() {
    const category = categories.find((item) => item.enabled) ?? categories[0];
    return {
      categoryId: category?.id || "",
      sort: 100,
      enabled: true
    };
  }

  function openCreateCategory() {
    setEditingCategory(null);
    categoryForm.resetFields();
    categoryForm.setFieldsValue(categoryFormInitialValues());
    setCategoryModalOpen(true);
  }

  function openEditCategory(record: AdminCategory) {
    setEditingCategory(record);
    categoryForm.resetFields();
    categoryForm.setFieldsValue({
      ...categoryFormInitialValues(),
      ...record
    });
    setCategoryModalOpen(true);
  }

  function closeCategoryModal() {
    setCategoryModalOpen(false);
    setEditingCategory(null);
    categoryForm.resetFields();
  }

  async function submitCategory(values: Partial<AdminCategory>) {
    try {
      if (editingCategory) {
        await api.updateCategory(editingCategory.id, normalizeTaxonomyPayload(values));
        message.success("分类已更新");
      } else {
        await api.createCategory(normalizeTaxonomyPayload(values));
        message.success("分类已创建");
      }
      closeCategoryModal();
      await load();
    } catch (error) {
      message.error(error instanceof Error ? error.message : editingCategory ? "更新分类失败" : "创建分类失败");
    }
  }

  function confirmDeleteCategory(record: AdminCategory) {
    modal.confirm({
      title: `删除 ${record.name}`,
      content: "删除后该分类和下属分组会停用，客户端不会再展示对应分类。",
      okText: "删除",
      okButtonProps: { danger: true },
      cancelText: "取消",
      onOk: () => deleteCategory(record)
    });
  }

  async function deleteCategory(record: AdminCategory) {
    try {
      await api.deleteCategory(record.id);
      message.success("分类已停用");
      await load();
    } catch (error) {
      message.error(error instanceof Error ? error.message : "删除分类失败");
    }
  }

  function openCreateGroup() {
    setEditingGroup(null);
    groupForm.resetFields();
    groupForm.setFieldsValue(groupFormInitialValues());
    setGroupModalOpen(true);
  }

  function openEditGroup(record: AdminGroup) {
    setEditingGroup(record);
    groupForm.resetFields();
    groupForm.setFieldsValue({
      ...groupFormInitialValues(),
      ...record
    });
    setGroupModalOpen(true);
  }

  function closeGroupModal() {
    setGroupModalOpen(false);
    setEditingGroup(null);
    groupForm.resetFields();
  }

  async function submitGroup(values: Partial<AdminGroup>) {
    try {
      if (editingGroup) {
        await api.updateGroup(editingGroup.id, normalizeTaxonomyPayload(values));
        message.success("分组已更新");
      } else {
        await api.createGroup(normalizeTaxonomyPayload(values));
        message.success("分组已创建");
      }
      closeGroupModal();
      await load();
    } catch (error) {
      message.error(error instanceof Error ? error.message : editingGroup ? "更新分组失败" : "创建分组失败");
    }
  }

  function confirmDeleteGroup(record: AdminGroup) {
    modal.confirm({
      title: `删除 ${record.name}`,
      content: "删除后该分组会停用，客户端不会再展示对应分组。",
      okText: "删除",
      okButtonProps: { danger: true },
      cancelText: "取消",
      onOk: () => deleteGroup(record)
    });
  }

  async function deleteGroup(record: AdminGroup) {
    try {
      await api.deleteGroup(record.id);
      message.success("分组已停用");
      await load();
    } catch (error) {
      message.error(error instanceof Error ? error.message : "删除分组失败");
    }
  }

  function openLinkModal(record: AdminApp) {
    setLinkTargetApp(record);
    setGeneratedLinks(buildGeneratedDeepLinks(record, mappings, platformConfig, window.location.origin));
    setLinkModalOpen(true);
  }

  function closeLinkModal() {
    setLinkModalOpen(false);
    setLinkTargetApp(null);
    setGeneratedLinks([]);
  }

  async function copyLink(value: string) {
    try {
      if (!navigator.clipboard?.writeText) {
        throw new Error("Clipboard is unavailable");
      }
      await navigator.clipboard.writeText(value);
      message.success("已复制");
    } catch {
      message.error("复制失败，请手动复制");
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

  async function savePlatformConfig(values: PlatformConfig) {
    setPlatformBusy(true);
    try {
      const result = await api.updatePlatformConfig(values);
      setPlatformConfig(result.data);
      setConfigCdnUrls(result.cdnUrls);
      platformForm.setFieldsValue(platformFormValues(result.data));
      message.success("远程配置已保存");
    } catch (error) {
      message.error(error instanceof Error ? error.message : "保存失败");
    } finally {
      setPlatformBusy(false);
    }
  }

  async function previewPlatformConfig() {
    setPlatformBusy(true);
    try {
      const result = await api.previewPlatformConfig();
      setConfigPreview(result.data as unknown as Record<string, unknown>);
      message.success("配置预览已生成");
    } catch (error) {
      message.error(error instanceof Error ? error.message : "预览失败");
    } finally {
      setPlatformBusy(false);
    }
  }

  async function testEntrypoints() {
    setPlatformBusy(true);
    try {
      const result = await api.testPlatformEntrypoints();
      setEntrypointResults(result.data);
      message.success("入口探测完成");
    } catch (error) {
      message.error(error instanceof Error ? error.message : "探测失败");
    } finally {
      setPlatformBusy(false);
    }
  }

  async function testR2() {
    setPlatformBusy(true);
    try {
      const result = await api.testR2();
      setR2Result(result);
      message.success("R2 测试完成");
    } catch (error) {
      setR2Result(null);
      message.error(error instanceof Error ? error.message : "R2 测试失败");
    } finally {
      setPlatformBusy(false);
    }
  }

  async function publishPlatformConfig() {
    setPlatformBusy(true);
    try {
      const result = await api.publishPlatformConfig();
      setConfigPreview(result as Record<string, unknown>);
      message.success("远程配置已发布");
    } catch (error) {
      message.error(error instanceof Error ? error.message : "发布失败");
    } finally {
      setPlatformBusy(false);
    }
  }

  const menuItems = [
    { key: "overview", icon: <BarChartOutlined />, label: "概览" },
    { key: "apps", icon: <AppstoreOutlined />, label: "App 管理" },
    { key: "taxonomy", icon: <AppstoreOutlined />, label: "分类配置" },
    { key: "deeplink", icon: <LinkOutlined />, label: "深链接" },
    { key: "platform", icon: <SettingOutlined />, label: "远程配置" },
    { key: "diagnostics", icon: <CloudUploadOutlined />, label: "发布检测" }
  ];

  const activeMeta = sectionMeta[activeSection];

  function renderMetrics() {
    return (
      <section className="metric-grid">
        <Metric icon={<AppstoreOutlined />} label="上架 App" value={summary?.enabled_apps ?? 0} />
        <Metric icon={<ApiOutlined />} label="IPA / H5" value={`${summary?.ipa_apps ?? 0}/${summary?.web_apps ?? 0}`} />
        <Metric icon={<LinkOutlined />} label="外部映射" value={summary?.mappings ?? mappings.length} />
        <Metric icon={<BarChartOutlined />} label="今日事件" value={summary?.events?.today_events ?? 0} />
      </section>
    );
  }

  function renderAppsPanel() {
    return (
      <section className="panel glass">
        <div className="panel-title">
          <div>
            <h2>App 列表</h2>
            <Text type="secondary">{apps.length} 个应用，按客户端展示顺序维护</Text>
          </div>
          <Space>
            <Tag color="blue">{apps.length} 个</Tag>
            <Button type="primary" icon={<PlusOutlined />} onClick={openCreateApp}>
              新增 App
            </Button>
          </Space>
        </div>
        <Table
          rowKey="id"
          loading={loading}
          columns={columns}
          dataSource={apps}
          size="middle"
          scroll={{ x: 1080 }}
          pagination={{ pageSize: 8, showSizeChanger: false }}
        />
      </section>
    );
  }

  function renderTaxonomyPanel() {
    return (
      <section className="taxonomy-grid">
        <div className="panel glass">
          <div className="panel-title">
            <div>
              <h2>分类</h2>
              <Text type="secondary">客户端顶部 tab 读取这里的启用分类。</Text>
            </div>
            <Button type="primary" icon={<PlusOutlined />} onClick={openCreateCategory}>
              新增分类
            </Button>
          </div>
          <Table
            rowKey="id"
            loading={loading}
            columns={categoryColumns}
            dataSource={categories}
            size="middle"
            scroll={{ x: 680 }}
            pagination={false}
          />
        </div>

        <div className="panel glass">
          <div className="panel-title">
            <div>
              <h2>分组</h2>
              <Text type="secondary">每个 App 需要归属到一个分类下的分组。</Text>
            </div>
            <Button type="primary" icon={<PlusOutlined />} onClick={openCreateGroup}>
              新增分组
            </Button>
          </div>
          <Table
            rowKey="id"
            loading={loading}
            columns={groupColumns}
            dataSource={groups}
            size="middle"
            scroll={{ x: 830 }}
            pagination={false}
          />
        </div>
      </section>
    );
  }

  function renderDeeplinkPanel() {
    return (
      <section className="panel glass narrow-panel">
        <div className="panel-title">
          <div>
            <h2>深链接测试</h2>
            <Text type="secondary">输入落地页参数，检查客户端最终打开的目标 App。</Text>
          </div>
          <Tag>Resolve</Tag>
        </div>
        <Form
          form={deeplinkForm}
          layout="vertical"
          initialValues={{ app_id: "3101", p_channel: "wc2dc", plat: "3" }}
          onFinish={resolveDeeplink}
        >
          <div className="form-grid-3">
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
          </div>
          <Space wrap>
            <Button type="primary" htmlType="submit">
              解析目标 App
            </Button>
            <Button onClick={sendTestEvent}>上报测试事件</Button>
          </Space>
        </Form>

        {deeplinkResult ? <ResultBlock title="解析结果" value={deeplinkResult} /> : null}
      </section>
    );
  }

  function renderPlatformPanel() {
    return (
      <section className="panel glass config-panel">
        <div className="panel-title">
          <div>
            <h2>远程配置</h2>
            <Text type="secondary">修改后先保存，再到发布检测页执行连通性检测和发布。</Text>
          </div>
          <Space wrap>
            {platformConfig?.github?.tokenConfigured ? <Tag color="green">GitHub 已配置</Tag> : <Tag>GitHub 未配置</Tag>}
            {platformConfig?.r2?.accessKeyIdConfigured ? <Tag color="green">R2 已配置</Tag> : <Tag>R2 未配置</Tag>}
          </Space>
        </div>
        <Form
          form={platformForm}
          layout="vertical"
          onFinish={savePlatformConfig}
          disabled={platformBusy}
          initialValues={{
            apiEntrypoints: [{ baseUrl: "https://666999.lol", enabled: true, weight: 100 }],
            github: { owner: "yasuo185239-beep", repo: "appbox-config", branch: "main", filePath: "version.json" },
            r2: {}
          }}
        >
          <div className="config-grid">
            <div>
              <Divider orientation="left">入口域名</Divider>
              <Form.List name="apiEntrypoints">
                {(fields, { add, remove }) => (
                  <Space direction="vertical" style={{ width: "100%" }}>
                    {fields.map((field) => (
                      <Space key={field.key} align="baseline" className="endpoint-row">
                        <Form.Item
                          {...field}
                          name={[field.name, "baseUrl"]}
                          rules={[{ required: true, type: "url", message: "请输入 HTTPS 入口域名" }]}
                        >
                          <Input placeholder="https://666999.lol" />
                        </Form.Item>
                        <Form.Item {...field} name={[field.name, "weight"]}>
                          <InputNumber min={0} style={{ width: 92 }} />
                        </Form.Item>
                        <Form.Item {...field} name={[field.name, "enabled"]} valuePropName="checked">
                          <Switch />
                        </Form.Item>
                        <Button onClick={() => remove(field.name)}>移除</Button>
                      </Space>
                    ))}
                    <Button onClick={() => add({ baseUrl: "", enabled: true, weight: 100 })}>添加入口域名</Button>
                  </Space>
                )}
              </Form.List>

              <Divider orientation="left">GitHub 配置仓库</Divider>
              <div className="form-grid-2">
                <Form.Item name={["github", "owner"]} label="Owner" rules={[{ required: true }]}>
                  <Input />
                </Form.Item>
                <Form.Item name={["github", "repo"]} label="Repo" rules={[{ required: true }]}>
                  <Input />
                </Form.Item>
                <Form.Item name={["github", "branch"]} label="Branch" rules={[{ required: true }]}>
                  <Input />
                </Form.Item>
                <Form.Item name={["github", "filePath"]} label="文件路径" rules={[{ required: true }]}>
                  <Input />
                </Form.Item>
              </div>
              <Form.Item name={["github", "token"]} label={`GitHub Token ${platformConfig?.github?.tokenMasked || ""}`}>
                <Input.Password placeholder="留空则保留当前 token" />
              </Form.Item>
            </div>

            <div>
              <Divider orientation="left">Cloudflare R2</Divider>
              <div className="form-grid-2">
                <Form.Item name={["r2", "accountId"]} label="Account ID">
                  <Input />
                </Form.Item>
                <Form.Item name={["r2", "bucket"]} label="Bucket">
                  <Input />
                </Form.Item>
                <Form.Item name={["r2", "endpoint"]} label="Endpoint">
                  <Input placeholder="https://<account>.r2.cloudflarestorage.com" />
                </Form.Item>
                <Form.Item name={["r2", "publicBaseUrl"]} label="公开 CDN 地址">
                  <Input placeholder="https://cdn.example.com" />
                </Form.Item>
              </div>
              <Form.Item name={["r2", "accessKeyId"]} label={`Access Key ${platformConfig?.r2?.accessKeyIdMasked || ""}`}>
                <Input.Password placeholder="留空则保留当前 key" />
              </Form.Item>
              <Form.Item
                name={["r2", "secretAccessKey"]}
                label={`Secret Key ${platformConfig?.r2?.secretAccessKeyMasked || ""}`}
              >
                <Input.Password placeholder="留空则保留当前 secret" />
              </Form.Item>
              <Form.Item name={["r2", "apiToken"]} label={`CF API Token ${platformConfig?.r2?.apiTokenMasked || ""}`}>
                <Input.Password placeholder="可选，用于后续 CDN purge" />
              </Form.Item>
            </div>
          </div>

          <Space wrap>
            <Button type="primary" htmlType="submit" loading={platformBusy}>
              保存配置
            </Button>
            <Button onClick={() => setActiveSection("diagnostics")}>去发布检测</Button>
          </Space>
        </Form>
      </section>
    );
  }

  function renderDiagnosticsPanel() {
    return (
      <section className="panel glass">
        <div className="panel-title">
          <div>
            <h2>发布检测</h2>
            <Text type="secondary">配置保存后，在这里完成入口、R2、密文预览和发布验证。</Text>
          </div>
          <Tag icon={<SettingOutlined />}>CDN</Tag>
        </div>
        <Space wrap className="action-row">
          <Button onClick={testEntrypoints} icon={<ApiOutlined />} loading={platformBusy}>
            测试入口
          </Button>
          <Button onClick={testR2} icon={<CloudUploadOutlined />} loading={platformBusy}>
            测试 R2
          </Button>
          <Button onClick={previewPlatformConfig} loading={platformBusy}>
            预览密文
          </Button>
          <Button danger onClick={publishPlatformConfig} loading={platformBusy}>
            发布到 GitHub/CDN
          </Button>
        </Space>

        <div className="config-result-grid">
          <ResultBlock title="CDN 配置源" value={configCdnUrls} />
          <ResultBlock title="入口探测" value={entrypointResults} />
          <ResultBlock title="R2 测试" value={r2Result} />
          <ResultBlock title="发布/预览" value={configPreview} />
        </div>
      </section>
    );
  }

  function renderCurrentSection() {
    if (activeSection === "overview") {
      return (
        <div className="page-stack">
          {renderMetrics()}
          <div className="content-grid">
            {renderAppsPanel()}
            {renderDeeplinkPanel()}
          </div>
        </div>
      );
    }
    if (activeSection === "apps") return renderAppsPanel();
    if (activeSection === "taxonomy") return renderTaxonomyPanel();
    if (activeSection === "deeplink") return renderDeeplinkPanel();
    if (activeSection === "platform") return renderPlatformPanel();
    return renderDiagnosticsPanel();
  }

  return (
    <Layout className="admin-layout" hasSider>
      <Layout.Sider className="admin-sider" width={248}>
        <div className="sider-brand">
          <div className="brand-mark">盒</div>
          <div>
            <h1>天涯盒子</h1>
            <p>管理后台</p>
          </div>
        </div>
        <Menu
          className="admin-menu"
          mode="inline"
          selectedKeys={[activeSection]}
          items={menuItems}
          onClick={({ key }) => setActiveSection(key as AdminSection)}
        />
        <div className="sider-footer">
          <Text type="secondary">API</Text>
          <Text ellipsis>{api.baseUrl || "same-origin"}</Text>
        </div>
      </Layout.Sider>

      <Layout className="admin-main">
        <header className="admin-header glass">
          <div>
            <Text type="secondary">天涯盒子管理后台</Text>
            <h1>{activeMeta.title}</h1>
            <p>{activeMeta.description}</p>
          </div>
          <Space wrap>
            <Button icon={<ReloadOutlined />} onClick={load} loading={loading}>
              刷新
            </Button>
            <Button icon={<LogoutOutlined />} onClick={logout}>
              退出
            </Button>
          </Space>
        </header>

        <main className="admin-content">{renderCurrentSection()}</main>
      </Layout>

      <Modal
        title={editingApp ? "编辑 App" : "新增 App"}
        open={modalOpen}
        onCancel={closeAppModal}
        onOk={() => form.submit()}
        destroyOnHidden
      >
        <Form
          form={form}
          layout="vertical"
          initialValues={appFormInitialValues()}
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
            <Select
              options={categories.map((item) => ({
                value: item.id,
                label: item.enabled ? item.name : `${item.name}（停用）`,
                disabled: !item.enabled
              }))}
              onChange={(categoryId) => {
                const group = groups.find((item) => item.enabled && item.categoryId === categoryId);
                form.setFieldValue("groupId", group?.id || "");
              }}
            />
          </Form.Item>
          <Form.Item shouldUpdate noStyle>
            {({ getFieldValue }) => {
              const categoryId = getFieldValue("categoryId");
              const options = groups
                .filter((item) => item.categoryId === categoryId)
                .map((item) => ({
                  value: item.id,
                  label: item.enabled ? item.name : `${item.name}（停用）`,
                  disabled: !item.enabled
                }));
              return (
                <Form.Item name="groupId" label="分组" rules={[{ required: true }]}>
                  <Select options={options} placeholder="请先选择分类" />
                </Form.Item>
              );
            }}
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
          <div className="form-grid-2">
            <Form.Item name="sort" label="排序">
              <InputNumber min={0} style={{ width: "100%" }} />
            </Form.Item>
            <Form.Item name="enabled" label="上架" valuePropName="checked">
              <Switch />
            </Form.Item>
            <Form.Item name="recommended" label="推荐" valuePropName="checked">
              <Switch />
            </Form.Item>
          </div>
        </Form>
      </Modal>

      <Modal
        title={editingCategory ? "编辑分类" : "新增分类"}
        open={categoryModalOpen}
        onCancel={closeCategoryModal}
        onOk={() => categoryForm.submit()}
        destroyOnHidden
      >
        <Form
          form={categoryForm}
          layout="vertical"
          initialValues={categoryFormInitialValues()}
          onFinish={submitCategory}
        >
          {!editingCategory ? (
            <Form.Item name="id" label="分类 ID">
              <Input placeholder="可留空自动生成，例如 tools" />
            </Form.Item>
          ) : null}
          <Form.Item name="name" label="名称" rules={[{ required: true }]}>
            <Input placeholder="工具系列" />
          </Form.Item>
          <Form.Item name="englishName" label="英文名">
            <Input placeholder="Tools" />
          </Form.Item>
          <div className="form-grid-2">
            <Form.Item name="sort" label="排序">
              <InputNumber min={0} style={{ width: "100%" }} />
            </Form.Item>
            <Form.Item name="enabled" label="启用" valuePropName="checked">
              <Switch />
            </Form.Item>
          </div>
        </Form>
      </Modal>

      <Modal
        title={editingGroup ? "编辑分组" : "新增分组"}
        open={groupModalOpen}
        onCancel={closeGroupModal}
        onOk={() => groupForm.submit()}
        destroyOnHidden
      >
        <Form
          form={groupForm}
          layout="vertical"
          initialValues={groupFormInitialValues()}
          onFinish={submitGroup}
        >
          {!editingGroup ? (
            <Form.Item name="id" label="分组 ID">
              <Input placeholder="可留空自动生成，例如 wallet" />
            </Form.Item>
          ) : null}
          <Form.Item name="categoryId" label="所属分类" rules={[{ required: true }]}>
            <Select
              options={categories.map((item) => ({
                value: item.id,
                label: item.enabled ? item.name : `${item.name}（停用）`,
                disabled: !item.enabled
              }))}
            />
          </Form.Item>
          <Form.Item name="name" label="名称" rules={[{ required: true }]}>
            <Input placeholder="钱包" />
          </Form.Item>
          <Form.Item name="englishName" label="英文名">
            <Input placeholder="Wallet" />
          </Form.Item>
          <div className="form-grid-2">
            <Form.Item name="sort" label="排序">
              <InputNumber min={0} style={{ width: "100%" }} />
            </Form.Item>
            <Form.Item name="enabled" label="启用" valuePropName="checked">
              <Switch />
            </Form.Item>
          </div>
        </Form>
      </Modal>

      <Modal
        title="生成深链接"
        open={linkModalOpen}
        onCancel={closeLinkModal}
        footer={
          <Space>
            <Button onClick={closeLinkModal}>关闭</Button>
            <Button
              type="primary"
              disabled={!generatedLinks[0]}
              onClick={() => generatedLinks[0] && copyLink(generatedLinks[0].value)}
            >
              复制首个链接
            </Button>
          </Space>
        }
        width={760}
        destroyOnHidden
      >
        {linkTargetApp ? (
          <div className="deep-link-modal">
            <div className="link-target">
              <img className="link-app-icon" src={linkTargetApp.iconUrl} alt="" />
              <div>
                <Text strong>{linkTargetApp.name}</Text>
                <Text type="secondary">
                  {linkTargetApp.id} · {linkTargetApp.type.toUpperCase()}
                </Text>
              </div>
            </div>
            <Text type="secondary">
              Scheme 用于手机直接唤起盒子；落地页链接用于外部网页按钮跳转或投放参数承接。
            </Text>
            <div className="link-result-list">
              {generatedLinks.map((link) => (
                <div className="link-result-card" key={`${link.label}-${link.value}`}>
                  <div className="link-result-head">
                    <div>
                      <Text strong>{link.label}</Text>
                      <Text type="secondary">{link.description}</Text>
                    </div>
                    <Button size="small" onClick={() => copyLink(link.value)}>
                      复制
                    </Button>
                  </div>
                  <Input.TextArea className="link-value" value={link.value} readOnly autoSize />
                </div>
              ))}
            </div>
          </div>
        ) : null}
      </Modal>
    </Layout>
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

function ResultBlock({ title, value }: { title: string; value: unknown }) {
  return (
    <div className="config-result">
      <Text type="secondary">{title}</Text>
      <pre>{value ? JSON.stringify(value, null, 2) : "暂无数据"}</pre>
    </div>
  );
}

function normalizeAppPayload(values: Partial<AdminApp>): Partial<AdminApp> {
  const payload: Partial<AdminApp> = {
    ...values,
    sort: Number(values.sort ?? 100),
    enabled: Boolean(values.enabled),
    recommended: Boolean(values.recommended)
  };

  if (payload.type === "ipa") {
    delete payload.entryUrl;
  }
  if (payload.type === "web") {
    delete payload.bundleId;
    delete payload.downloadUrl;
  }
  return payload;
}

function normalizeTaxonomyPayload<T extends { enabled?: boolean; sort?: number }>(values: T): T {
  return {
    ...values,
    sort: Number(values.sort ?? 100),
    enabled: Boolean(values.enabled)
  };
}

function buildGeneratedDeepLinks(
  app: AdminApp,
  mappings: AdminMapping[],
  platformConfig: PlatformConfig | null,
  currentOrigin: string
): GeneratedDeepLink[] {
  const enabledMappings = mappings.filter((mapping) => mapping.enabled && mapping.appId === app.id);
  const sources = enabledMappings.length
    ? enabledMappings
    : [
        {
          id: `fallback-${app.id}`,
          appId: app.id,
          externalAppId: app.id,
          platform: "ios" as const,
          enabled: true
        }
      ];
  const baseURL = primaryBaseURL(platformConfig, currentOrigin);

  return sources.flatMap((mapping, index) => {
    const channel = mapping.channel?.trim();
    const plat = platformToPlat(mapping.platform);
    const suffix = sources.length > 1 ? ` ${index + 1}` : "";
    const mappingMeta = `${mapping.externalAppId} / ${platformLabel(mapping.platform)} / ${channel || "默认渠道"}`;

    const nativeParams = new URLSearchParams();
    nativeParams.set("data", app.id);
    nativeParams.set("app_id", mapping.externalAppId);
    nativeParams.set("plat", plat);
    if (channel) nativeParams.set("channel", channel);

    const landingParams = new URLSearchParams();
    landingParams.set("data", app.id);
    landingParams.set("app_id", mapping.externalAppId);
    landingParams.set("plat", plat);
    if (channel) landingParams.set("p_channel", channel);

    return [
      {
        label: `Scheme 链接${suffix}`,
        description: `手机直接打开 · ${mappingMeta}`,
        value: `appbox://native?${nativeParams.toString()}`
      },
      {
        label: `落地页链接${suffix}`,
        description: `网页按钮跳转 · ${mappingMeta}`,
        value: `${baseURL}/landing?${landingParams.toString()}`
      }
    ];
  });
}

function primaryBaseURL(config: PlatformConfig | null, currentOrigin: string) {
  const configured = config?.apiEntrypoints?.find((entry) => entry.enabled && entry.baseUrl)?.baseUrl;
  return (configured || currentOrigin).replace(/\/+$/, "");
}

function platformToPlat(platform: AdminMapping["platform"]) {
  if (platform === "android") return "2";
  if (platform === "all") return "all";
  return "3";
}

function platformLabel(platform: AdminMapping["platform"]) {
  if (platform === "android") return "Android";
  if (platform === "all") return "All";
  return "iOS";
}

function platformFormValues(config: PlatformConfig): PlatformConfig {
  return {
    ...config,
    github: {
      owner: config.github.owner,
      repo: config.github.repo,
      branch: config.github.branch,
      filePath: config.github.filePath,
      token: ""
    },
    r2: {
      accountId: config.r2?.accountId || "",
      bucket: config.r2?.bucket || "",
      endpoint: config.r2?.endpoint || "",
      publicBaseUrl: config.r2?.publicBaseUrl || "",
      accessKeyId: "",
      secretAccessKey: "",
      apiToken: ""
    }
  };
}
