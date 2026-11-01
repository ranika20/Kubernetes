'use strict';

const express = require('express');
const os = require('node:os');

const fortunesByVersion = {
  v1: [
    'צעד קטן היום יפתח דלת גדולה מחר.',
    'סבלנות היא המרכיב הסודי בכל הצלחה.',
    'רעיון טוב משתפר כשחולקים אותו.',
    'הדרך קדימה מתחילה בצעד הראשון.',
    'הזדמנות חדשה תופיע במקום לא צפוי.',
    'החיוך שלך עשוי להיות המזל של מישהו אחר.',
    'התמדה הופכת חלומות לתוכניות.',
    'היום מתאים ללמוד משהו חדש.',
    'הפתרון קרוב יותר ממה שנדמה.',
    'מעשה קטן של טוב לב חוזר בדרך מפתיעה.'
  ],
  v2: [
    '[v2] אומץ לנסות הוא כבר חצי מההצלחה.',
    '[v2] שיתוף פעולה הופך רעיון טוב למצוין.',
    '[v2] כל אתגר מסתיר הזדמנות לצמוח.',
    '[v2] התמדה היא קסם שעובד גם בלי שרביט.',
    '[v2] מחשבה סקרנית מובילה לתגליות חדשות.',
    '[v2] התחלה חדשה יכולה להגיע בכל רגע.',
    '[v2] הצלחה נבנית מהרגלים קטנים.',
    '[v2] הקשבה טובה פותחת יותר דלתות מדיבור.',
    '[v2] שינוי קטן יכול ליצור תוצאה גדולה.',
    '[v2] הדרך הטובה ביותר לחזות את העתיד היא ליצור אותו.'
  ]
};

function createApp(options = {}) {
  const version = options.version || process.env.APP_VERSION || 'v1';
  const fortunes = fortunesByVersion[version] || fortunesByVersion.v1;
  const app = express();

  app.get('/healthz', (_request, response) => {
    response.status(200).json({ status: 'ok' });
  });

  app.get('/api/fortune', (_request, response) => {
    const fortune = fortunes[Math.floor(Math.random() * fortunes.length)];
    response.json({
      fortune,
      pod: os.hostname(),
      version
    });
  });

  return app;
}

if (require.main === module) {
  const port = Number(process.env.PORT || 3000);
  createApp().listen(port, '0.0.0.0', () => {
    console.log(`Fortune API listening on port ${port}`);
  });
}

module.exports = { createApp };
