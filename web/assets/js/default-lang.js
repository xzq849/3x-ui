// 设置默认语言为中文
document.addEventListener('DOMContentLoaded', function() {
    // 只在没有语言cookie的情况下设置默认语言
    if (!CookieManager.getCookie("lang")) {
        CookieManager.setCookie("lang", "zh-CN", 150);
        // 如果当前页面不是在刷新中，则刷新页面应用新语言
        if (!window.location.href.includes('refreshing')) {
            window.location.href = window.location.href + (window.location.href.includes('?') ? '&' : '?') + 'refreshing=true';
        }
    }
});