using System;
using System.Collections.Generic;
using UnityEngine;

namespace SausageReplay
{
    public class UnityMainThreadDispatcher : MonoBehaviour
    {
        private static UnityMainThreadDispatcher _instance;
        private static readonly Queue<Action> _executionQueue = new Queue<Action>();
        private static readonly object _lock = new object();
        private static bool _hasSearched = false;

        public static UnityMainThreadDispatcher Instance
        {
            get
            {
                if (_instance == null && !_hasSearched)
                {
                    _instance = FindObjectOfType<UnityMainThreadDispatcher>();
                    _hasSearched = true;
                    if (_instance == null)
                    {
                        GameObject go = new GameObject("UnityMainThreadDispatcher");
                        _instance = go.AddComponent<UnityMainThreadDispatcher>();
                        DontDestroyOnLoad(go);
                    }
                }
                return _instance;
            }
        }

        public static void Enqueue(Action action)
        {
            if (action == null) return;
            lock (_lock) { _executionQueue.Enqueue(action); }
        }

        public static void Enqueue<T>(Func<T> action, Action<T> callback)
        {
            if (action == null) return;
            Enqueue(() =>
            {
                try { T result = action(); callback?.Invoke(result); }
                catch (Exception e) { Debug.LogError($"Exception in main thread task: {e.Message}"); }
            });
        }

        private void Awake()
        {
            if (_instance == null) { _instance = this; _hasSearched = true; DontDestroyOnLoad(gameObject); }
            else if (_instance != this) { Destroy(gameObject); }
        }

        private void Update()
        {
            lock (_lock)
            {
                while (_executionQueue.Count > 0)
                {
                    try { Action action = _executionQueue.Dequeue(); action?.Invoke(); }
                    catch (Exception e) { Debug.LogError($"Exception in main thread dispatcher: {e.Message}"); }
                }
            }
        }

        private void OnDestroy()
        {
            if (_instance == this) { _instance = null; _hasSearched = false; }
        }
    }
}


