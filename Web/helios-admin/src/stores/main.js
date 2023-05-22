import { defineStore } from 'pinia'
import axios from 'axios'

var isDebug = true
var baseUrl = isDebug ? 'http://localhost:30000' : 'https://admin.yuusann.com'

export const useMainStorage = defineStore('main', {
  state: () => {
    return {
      count: 0,
    }
  },
  setup() {
    state.axios = inject('axios')
  },
  actions: {
    increment() {
      this.count++
    },

    sendGetRequest(path, completion) {
      const url = baseUrl + path
      axios.get(url).then((response) => {
        const success = response.data.success
        const message = response.data.message
        const data = response.data.data
        completion(success, null, message, data)
      }).catch((error) => {
        completion(false, error, null, null)
      })
    },

    sendPostRequest(path, data, completion) {
      const url = baseUrl + path
      axios.post(url, data).then((response) => {
        const success = response.data.success
        const message = response.data.message
        const data = response.data.data
        completion(success, null, message, data)
      }).catch((error) => {
        completion(false, error, null, null)
      })
    },

    sendActionRequest(path, action, query, data, completion) {
      var fullPath = path + "?action=" + action
      if (query != null) {
        fullPath += "&" + query
      }
      this.sendPostRequest(fullPath, data, completion)
    },

    formatDateTime(date, fmt) {
      var o = {
        "M+": date.getMonth() + 1,               //月份 
        "d+": date.getDate(),                    //日 
        "h+": date.getHours(),                   //小时 
        "m+": date.getMinutes(),                 //分 
        "s+": date.getSeconds(),                 //秒 
        "q+": Math.floor((date.getMonth() + 3) / 3), //季度 
        "S": date.getMilliseconds()             //毫秒 
      };
      if (/(y+)/.test(fmt)) {
        fmt = fmt.replace(RegExp.$1, (date.getFullYear() + "").substr(4 - RegExp.$1.length));
      }
      for (var k in o) {
        if (new RegExp("(" + k + ")").test(fmt)) {
          fmt = fmt.replace(RegExp.$1, (RegExp.$1.length == 1) ? (o[k]) : (("00" + o[k]).substr(("" + o[k]).length)));
        }
      }
      return fmt;
    }
  },
})
