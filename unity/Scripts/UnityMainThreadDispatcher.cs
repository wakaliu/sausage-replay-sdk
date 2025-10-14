using System;
using System.Collections.Generic;
using UnityEngine;

namespace SausageReplay
{
    /// <summary>
    /// Unity主线程调度器
    /// 用于将Android回调调度到Unity主线程执行
    /// </summary>
    public class UnityMainThreadDispatcher : MonoBehaviour
    {
        private static UnityMainThreadDispatcher _instance;
        private static readonly Queue<Action> _executionQueue = new Queue<Action>();
        private static readonly object _lock = new object();
        private static bool _hasSearched = false; // 添加搜索标记，避免重复查找

        /// <summary>
        /// 获取单例实例
        /// </summary>
        public static UnityMainThreadDispatcher Instance
        {
            get
            {
                if (_instance == null && !_hasSearched)
                {
                    // 只在第一次访问时查找，避免重复的FindObjectOfType调用
                    _instance = FindObjectOfType<UnityMainThreadDispatcher>();
                    _hasSearched = true; // 标记已搜索过
                    
                    if (_instance == null)
                    {
                        // 只有在找不到时才创建新对象
                        GameObject go = new GameObject("UnityMainThreadDispatcher");
                        _instance = go.AddComponent<UnityMainThreadDispatcher>();
                        DontDestroyOnLoad(go);
                    }
                }
                return _instance;
            }
        }

        /// <summary>
        /// 将任务加入主线程执行队列
        /// </summary>
        /// <param name="action">要执行的任务</param>
        public static void Enqueue(Action action)
        {
            if (action == null) return;

            lock (_lock)
            {
                _executionQueue.Enqueue(action);
            }
        }

        /// <summary>
        /// 将任务加入主线程执行队列（带返回值）
        /// </summary>
        /// <typeparam name="T">返回值类型</typeparam>
        /// <param name="action">要执行的任务</param>
        /// <param name="callback">结果回调</param>
        public static void Enqueue<T>(Func<T> action, Action<T> callback)
        {
            if (action == null) return;

            Enqueue(() =>
            {
                try
                {
                    T result = action();
                    callback?.Invoke(result);
                }
                catch (Exception e)
                {
                    Debug.LogError($"Exception in main thread task: {e.Message}");
                }
            });
        }

        private void Awake()
        {
            if (_instance == null)
            {
                _instance = this;
                _hasSearched = true; // 标记已找到实例，避免重复搜索
                DontDestroyOnLoad(gameObject);
            }
            else if (_instance != this)
            {
                Destroy(gameObject);
            }
        }

        private void Update()
        {
            lock (_lock)
            {
                while (_executionQueue.Count > 0)
                {
                    try
                    {
                        Action action = _executionQueue.Dequeue();
                        action?.Invoke();
                    }
                    catch (Exception e)
                    {
                        Debug.LogError($"Exception in main thread dispatcher: {e.Message}");
                    }
                }
            }
        }

        private void OnDestroy()
        {
            if (_instance == this)
            {
                _instance = null;
                _hasSearched = false; // 重置搜索标记，允许重新搜索
            }
        }
    }
}
