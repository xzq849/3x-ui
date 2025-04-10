// 初始化系统默认语言设置

// 在数据库中设置电报机器人默认语言为中文
class LangInitializer {
    static async initSystemLanguage() {
        try {
            // 检查是否已经初始化过语言设置
            const initFlag = localStorage.getItem('lang_initialized');
            if (initFlag === 'true') {
                return;
            }

            // 设置网页界面默认语言为中文
            if (!CookieManager.getCookie("lang")) {
                CookieManager.setCookie("lang", "zh-CN", 150);
            }

            // 设置电报机器人默认语言为中文
            const response = await HttpUtil.post('/panel/setting/update', {
                tgLang: 'zh-CN'
            });

            if (response.success) {
                console.log('系统语言初始化成功');
                localStorage.setItem('lang_initialized', 'true');
            }
        } catch (error) {
            console.error('初始化系统语言失败:', error);
        }
    }
}

// 在页面加载完成后执行初始化
document.addEventListener('DOMContentLoaded', function() {
    // 延迟执行，确保其他必要组件已加载
    setTimeout(() => {
        LangInitializer.initSystemLanguage();
    }, 1000);
});