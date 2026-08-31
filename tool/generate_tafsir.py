#!/usr/bin/env python3
"""Generate assets/quran_tafsir.json — curated tafsir for key ayahs."""
import json

E = []
def a(s, ay, t, c, src='Ibn Kathir'):
    E.append({'surah':s,'ayah':ay,'title':t,'commentary':c,'source':src})

# Al-Fatiha (1)
a(1,1,'Al-Hamdu Lillah — Opening of the Book','Every good matter begins with praising Allah. This surah is called Umm al-Kitab (Mother of the Book). It is obligatory in every rak\'ah of prayer and is the most recited surah in the Quran. Its seven verses encapsulate the entire essence of Islamic monotheism, worship, and supplication.'')
a(1,2,'Rabb al-Alamin — Lord of all the Worlds','Allah begins by praising Himself, the highest form of praise since no one knows Allah\'s true worth except He. Rabb means the One who nurtures, sustains, and governs all creation. Al-Alamin encompasses every realm of existence.'')
a(1,3,'Ar-Rahman Ar-Rahim — The Most Gracious, the Most Merciful','Ar-Rahman is the vast, all-encompassing mercy extending to all creation in this world. Ar-Rahim is the specific, sustained mercy reserved for the believers in the Hereafter. Some scholars said Ar-Rahman is a name unique to Allah, while Ar-Rahim could also describe a merciful person.'')
a(1,4,'Maliki yawm ad-Din — Master of the Day of Judgment','This ayah mentions Allah\'s absolute sovereignty over the Day of Judgment, when all creation will be gathered before Him. No one will have any authority on that Day except Allah. The word Malik denotes absolute ownership and dominion over all things.'')
a(1,5,'Iyyaka na\'budu wa iyyaka nasta\'in — You alone we worship','Worship is the highest station of servitude combining love, fear, and hope. "You alone we worship" establishes monotheism (tawhid), while "You alone we ask for help" affirms complete dependence on Allah. These two clauses together form the foundation of the Islamic creed.'')
a(1,6,'Ihdina as-Sirat al-Mustaqim — Guide us to the straight path','The straight path is the religion of Islam — the path of those whom Allah has favored. The Jews earned Allah\'s anger (by knowing the truth but hiding it) and the Christians went astray (by exceeding the bounds of their religion). This supplication asks for steadfastness until death.'')
a(1,7,'Sirat al-Ladhina an\'amta alayhim — The path of the favored','Those whom Allah has favored include the prophets, the truthful (siddiqin), the martyrs (shuhada), and the righteous (salihin). The anger mentioned is divine wrath that settles permanently, unlike ordinary anger. Going astray means wandering away from truth without guidance.'')

# Al-Baqarah (2)
a(2,2,'Dhalika al-Kitab — This is the Book','This is the first ayah revealed in Madinah. The Quran is described as guidance for the muttaqin (those with taqwa). There is no doubt in it — the People of the Book had doubts, but the Quran itself contains no ambiguity for those who reflect and surrender to its truth.'')
a(2,22,'Made the earth a resting place','Allah made the earth a stable dwelling, placed rivers and firm mountains within it, and provided fruits in pairs. All of this is a sign for people who reflect and take heed. The stability of the earth is a mercy that allows mankind to live and prosper.'')
a(2,25,'Give glad tidings to the believers','The gardens beneath which rivers flow contain fruits of every kind. Whenever the believers are given fruit, they will say "This is what we were provided before," for it will be presented in similar forms but different tastes — a sign of the endless variety of Paradise.'')
a(2,28,'How can you disbelieve?','Allah reminds mankind of the cycle of life: they were lifeless (non-existent), then He gave them life, then He will cause them to die, then bring them back to life. This continuous cycle should make them recognize Allah\'s absolute power and not deny the Resurrection.'')
a(2,30,'I am placing a successor on earth','When Allah told the angels He would place a khalifah on earth, Iblis objected. Allah responded "Indeed, I know what you do not know." The khalifah refers to Adam and his descendants, whom Allah honored with knowledge, authority, and the trust (amanah).'')
a(2,32,'Glory be to You, we have no knowledge','The angels acknowledged their limitations, saying "We have no knowledge except what You have taught us." This teaches that true knowledge comes from Allah alone. When Adam was taught the names of all things, the angels were humbled.'')
a(2,38,'Whoever follows My guidance','Allah promised that whoever follows His guidance "will not go astray or be miserable." This is a universal promise: sincere adherence to divine guidance leads to both worldly and spiritual success. Conversely, turning away from it brings only misery.'')
a(2,55,'Then the thunderbolt took you','When the Israelites demanded to see Allah directly, the thunderbolt struck them while they were looking. This severe punishment was for their audacity and lack of respect for the limits Allah had set. Despite witnessing such signs, many still worshipped the golden calf.'')
a(2,61,'We will not endure one kind of food','The Israelites complained about the单一 food (manna and salwa) and asked for the herbs, cucumbers, lentils, and onions of Egypt. Their homes were changed and they were struck with humiliation and wretchedness — their recompense for ingratitude.'')
a(2,67,'Slaughter a cow','The story of the cow teaches that excessive questioning and reluctance can make simple commands extremely difficult. The Israelites were commanded to sacrifice a cow, but their stubborn questioning turned a straightforward act into a near-impossible task.'')
a(2,83,'The covenant of the Children of Israel','Allah took a solemn covenant: worship none but Him, be kind to parents, relatives, orphans, and the needy, speak good to people, establish prayer, and give zakah. Then they turned away except for a few.'')
a(2,102,'They followed what the devils recited','Solomon\'s kingdom was not disbelief. The devils wrote books of sorcery and falsely attributed them to Solomon. People followed these works instead of the revelation. Allah declares that what was attributed to Solomon was not from him.'')
a(2,115,'To Allah belong the east and the west','Wherever you turn, the Face of Allah is there. All directions are equal in terms of Allah\'s presence. However, this does not abrogate the qiblah, which remained a test for the believers — distinguishing between Allah\'s omnipresence and prescribed acts of worship.'')
a(2,120,'The Jews will never be satisfied','The Jews will never be pleased with the Prophet Muhammad until he follows their religion. Say: "Indeed, the guidance of Allah is the [true] guidance." If you followed their desires after knowledge came to you, you would have no ally against Allah.'')
a(2,125,'We made the House a place of return','The Ka\'bah was made a place of return for people and a place of security. Ibrahim and Ismail were commanded to purify the House for those who circumambulate it, those who stay there for worship, and those who bow and prostrate.'')
a(2,129,'Send among them a Messenger','Ibrahim supplicated for a Messenger from among the Arabs who would recite Allah\'s verses, teach the Book and wisdom, and purify them. This prayer was answered with the Prophet Muhammad.'')
a(2,136,'We will not differentiate between His Messengers','The believers say: "We believe in Allah and what was revealed to us, and what was revealed to Ibrahim, Ismail, Isaac, Jacob, the tribes, and what was given to Musa, Isa, and the prophets from their Lord. We make no distinction between any of them."'')
a(2,143,'Thus We made you a middle nation','Allah made the Muslim ummah a justly balanced nation (wasat) — moderate in all affairs, neither extreme nor negligent. The change of qiblah was a test of sincerity — "only that We might know who followed the Messenger from those who turned back."'')
a(2,148,'To each [community] a direction they face','Each community has its direction toward which it turns. So compete in good deeds. Wherever you are, Allah will bring you all together. The competition should be in righteousness, not in differences of direction or ritual.'')
a(2,152,'Remember Me, and I will remember you','One of the most beautiful promises in the Quran. If you remember Allah through obedience, worship, and gratitude, He will remember you with reward, protection, and care. Allah\'s response to His servant\'s remembrance is far greater than the servant\'s remembrance of Allah.'')
a(2,155,'We will surely test you','Allah tests through fear, hunger, loss of wealth, lives, and crops. But give good tidings to the patient — those who, when a calamity strikes, say "Indeed, to Allah we belong and to Him we shall return." They are the ones upon whom are blessings and mercy.'')
a(2,177,'Righteousness is not in turning your faces','True righteousness is not merely facing east or west in prayer, but: believing in Allah, the Last Day, the angels, the Books, and the prophets; giving wealth to relatives, orphans, the needy; establishing prayer and giving zakah.'')
a(2,183,'Fasting has been prescribed for you','Fasting was prescribed for those before you so that you may attain taqwa (God-consciousness). It is a means of purification of the soul and body, developing gratitude for Allah\'s blessings, and learning to control desires.'')
a(2,185,'The month of Ramadan','Ramadan is the month in which the Quran was revealed as a guidance for mankind. Whoever witnesses this month should fast it. The Night of Power (Laylat al-Qadr) is better than a thousand months.'')
a(2,186,'When My servants ask you about Me','Allah is near and responds to the supplication of the supplicant. Tell them: "I am near. I respond to the call of the caller when he calls upon Me." This ayah encompasses all forms of supplication and gives hope to every servant.'')
a(2,195,'Spend in the way of Allah','Do not throw yourselves into destruction by being stingy. Do good, for Allah loves the doers of good. Spending in Allah\'s cause includes charity, supporting the community, and all forms of righteous expenditure.'')
a(2,216,'Fighting has been enjoined upon you','Jihad is prescribed even though you dislike it. You may hate a thing which is good for you, and love a thing which is bad for you. Allah knows and you do not know. Human judgment of benefit is limited while Allah\'s knowledge is complete.'')
a(2,222,'They ask you about menstruation','Menstruation is a natural condition. The prohibition is on marital relations during this period. The instruction to "keep away from them" and then "when they have purified themselves, approach them" shows clear rules for a temporary state.'')
a(2,223,'Your wives are a tilth for you','Wives are a place of planting and sowing, i.e., for procreation. The key teaching is that intimate relations should be conducted with decency. This was revealed when companions asked about the manner of relations.'')
a(2,228,'Divorced women wait three menstrual cycles','Divorced women must observe iddah of three menstrual cycles before remarrying. During this time, their husbands may take them back if they wish to reconcile. This period allows for reflection and reconciliation.'')
a(2,233,'Mothers may breastfeed their children','The mother has the right to breastfeed her children for two complete years if the father wishes. Both parents share in the cost. No soul is burdened beyond its capacity. This addresses the rights of mothers, fathers, and children.'')
a(2,245,'Who will loan Allah a goodly loan?','Allah presents Himself as borrowing from His servants, out of His generosity. He multiplies the reward seven hundredfold or more. Charity does not diminish wealth — it increases it through Allah\'s multiplication and barakah.'')
a(2,249,'When you march forth in the cause of Allah','When Saul led the Israelites to fight, he tested them with the river: whoever drank from it was not with him. The sincere ones drank only a handful. True faith is tested in times of hardship and scarcity, not comfort.'')
a(2,255,'Ayat al-Kursi — The Throne Verse','This is the greatest ayah in the Quran. Allah is the Eternal, the Sustainer of all existence. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and the earth. His Kursi extends over the heavens and the earth, and He is not fatigued by their preservation. Reciting it before sleep is a protection.'')
a(2,261,'The example of those who spend','The example of those who spend their wealth in Allah\'s cause is like a grain that produces seven ears, each bearing a hundred grains. Allah multiplies the reward for whom He wills. Charity does not diminish wealth — it increases it.'')
a(2,264,'O you who believe — do not nullify charity','Do not nullify your charitable deeds with reminders of your generosity or by harming others. Like someone who spends his wealth to show off but does not believe in Allah or the Last Day. True charity is given purely for Allah\'s sake.'')
a(2,269,'He gives wisdom to whom He wills','Wisdom is understanding the Quran and Sunnah correctly and applying them properly. It is given by Allah to whom He wills. None remember the reminders except those of understanding — wisdom is the fruit of beneficial knowledge.'')
a(2,274,'Those who spend their wealth','Their wealth is not diminished by charity; rather, it is multiplied. They seek no reward or thanks from people. Their reward is with their Lord, and they will have no fear, nor will they grieve.'')
a(2,282,'When you contract a debt — the longest verse','This is the longest verse in the Quran, detailing the rules of recording debts. It commands writing down debts with witnesses and emphasizes God-consciousness. The instruction to "fear Allah" frames the entire transaction in piety.'')
a(2,284,'To Allah belongs whatever is in the heavens','Whether you reveal what is in your hearts or conceal it, Allah will call you to account. He forgives whom He wills and punishes whom He wills. Nothing escapes Allah\'s knowledge, whether hidden or apparent.'')
a(2,285,'The Messenger believes in what was revealed','The Prophet believes in what was revealed from his Lord, as do the believers. They all believe in Allah, His angels, His Books, and His Messengers. "We make no distinction between any of His Messengers" — the foundational creed.'')
a(2,286,'Allah does not burden a soul beyond its capacity','Every person receives only what they are able to bear. Good deeds are recorded and evil deeds are recorded. The Prophet will intercede on the Day of Judgment. This ayah is a source of comfort for every struggling believer.'')

# Ali 'Imran (3)
a(3,8,'Our Lord, let not our hearts deviate','The believers pray for steadfastness after guidance. This acknowledges that guidance is from Allah alone and that the heart can deviate even after receiving it — hence the constant need for divine assistance.'')
a(3,26,'Say: O Allah, Owner of sovereignty','You give sovereignty to whom You will and take it away from whom You will. You honor whom You will and humble whom You will. In Your hand is all good. You are over all things competent.'')
a(3,45,'When the angels said, O Maryam','The angels gave Maryam the glad tidings of a Word from Allah whose name will be the Messiah, Isa, son of Maryam, honored in this world and the Hereafter. He will be among the near ones to Allah.'')
a(3,51,'Indeed, Allah is my Lord and your Lord','Isa declared: "Indeed, Allah is my Lord and your Lord, so worship Him. This is the straight path." Isa explicitly called to monotheism and rejected any divinity being attributed to him.'')
a(3,54,'They planned and Allah planned','Allah is the best of planners. Despite all schemes against Isa, Allah raised him to Himself and protected him. No matter what plots are hatched against believers, Allah\'s plan is superior.'')
a(3,59,'The example of Isa','The example of Isa before Allah is like that of Adam — He created him from dust and said "Be," and he was. If Adam could be created without a father, Isa\'s creation without a father is well within Allah\'s power.'')
a(3,67,'Ibrahim was not a Jew nor a Christian','Ibrahim was neither a Jew nor a Christian, but a pure monotheist (hanif), a Muslim. He was not of the polytheists. Ibrahim\'s creed of pure monotheism is the foundation of Islam.'')
a(3,85,'Whoever seeks other than Islam','Whoever seeks a religion other than Islam, it will never be accepted from him. Islam is the submission to Allah alone through His prophets, and no other path is accepted. This applies to all of humanity for all time.'')
a(3,139,'Do not weaken and do not grieve','After the Battle of Uhud, where the Muslims suffered losses, Allah commanded them not to weaken or grieve. "You will be superior if you are [true] believers." Their reward is tied to sincerity and patience.'')
a(3,185,'Every soul will taste death','Every soul will taste death, and you will be paid your wages on the Day of Resurrection. Whoever is drawn away from the Fire and admitted to Paradise has succeeded. The life of this world is only the enjoyment of delusion.'')
a(3,190,'Indeed, in the creation of the heavens and the earth','The scholars contemplate the signs of Allah in the universe and remember Allah while standing, sitting, or lying down. They reflect: "Our Lord, You did not create this without purpose." This is the highest form of worship through contemplation.'')

# An-Nisa (4)
a(4,1,'O mankind, be conscious of your Lord','Allah begins by commanding all of mankind to have taqwa of their Lord who created them from one soul. From that soul He created its mate, and from them He spread forth many men and women. The highest status is through taqwa, not lineage or wealth.'')
a(4,11,'Allah enjoins concerning your children — inheritance','The inheritance shares: the male receives the share of two females. If more than two daughters, they receive two-thirds. If one daughter, she receives half. These rules establish clear, divinely-ordained rights and eliminate disputes over inheritance.'')
a(4,34,'Men are the protectors of women','Men are guardians over women by virtue of what Allah has given some over others and because they spend from their wealth. The righteous women are devoutly obedient. As for those from whom you fear disobedience, admonish them, sleep apart, then separate.'')
a(4,59,'Obey Allah and the Messenger','Obey Allah and the Messenger and those in authority among you. If you differ, refer it to Allah and the Messenger. This establishes the hierarchy: Allah first, then His Messenger, then those in authority.'')
a(4,65,'And you will find most of them','You will find most people to be disbelievers, except those who believe and do righteous deeds — and few are they. The path of faith is the minority path.'')
a(4,75,'What is the matter with you that you do not fight','Allah questions why the believers do not fight for the oppressed — men, women, and children who cry out "Our Lord, deliver us from this town whose people are oppressors." This establishes the obligation of defending the oppressed.'')
a(4,135,'O you who believe, be persistently standing firm in justice','Be steadfast in justice, witnesses for Allah, even if against yourselves, your parents, or your relatives. Do not let hatred prevent you from being just. Justice is closer to taqwa.'')

# Al-Ma'idah (5)
a(5,3,'Forbidden to you are dead animals','This ayah details the dietary prohibitions: dead meat, blood, flesh of swine, what has been slaughtered for other than Allah, what has been killed by strangling, violent blow, fall, goring, or eaten by wild animals. Exceptions exist for travelers and those in necessity without transgressing limits.'')
a(5,90,'Intoxicants, gambling, and altars','Khamr (intoxicants), gambling, stone altars, and divining arrows are defilement from Shaytan, so avoid them that you may be successful. Shaytan seeks to incite enmity and hatred and to divert you from the remembrance of Allah and from prayer.'')

# Al-An'am (6)
a(6,38,'No creature moves on earth nor bird','No creature moves on earth nor bird that flies but they are communities like you. We have not neglected anything in the Book. Then to their Lord they will be gathered.'')
a(6,59,'With Him are the keys of the unseen','No one knows the unseen except Allah. He knows what is on the land and in the sea. Not a leaf falls except that He knows it. There is no grain in the darkness of the earth, nor anything fresh or dry, except that it is in a clear Record.'')
a(6,102,'That is Allah, your Lord','There is no deity except Him, the Creator of all things, so worship Him. Recognizing Allah as Creator naturally leads to worshiping Him alone.'')

# Al-A'raf (7)
a(7,31,'O Children of Adam — adornment at every masjid','Take your adornment (clean clothes) at every masjid, and eat and drink, but do not be excessive. This commands cleanliness for worship, permits eating and drinking, but warns against extravagance.'')
a(7,33,'My Lord has only forbidden — the major sins','The major sins are: indecency (public or private), sin, transgression without right, associating partners with Allah without authority, and saying about Allah what you do not know.'')

# Al-Anfal (8)
a(8,2,'The believers are only those','True believers are those whose hearts tremble when Allah is mentioned, whose faith increases when His verses are recited, who trust in their Lord, establish prayer, and spend from what We provided them.'')
a(8,24,'O you who believe, respond to Allah','Respond to Allah and the Messenger when he calls you to that which gives you life. Know that Allah intervenes between a person and his heart, and to Him you will be gathered. Respond with urgency — death can come at any moment.'')

# At-Tawbah (9)
a(9,111,'Indeed, Allah has purchased','Allah has purchased from the believers their lives and their wealth in exchange for Paradise. They fight in the cause of Allah, so they kill and are killed. This is a true promise binding in the Torah, the Gospel, and the Quran.'')

# Yunus (10)
a(10,57,'O mankind, there has come to you','There has come to you an instruction from your Lord and a healing for what is in the breasts — a guidance and mercy for the believers. The Quran is a shifa (healing) for the diseases of the heart.'')

# Hud (11)
a(11,114,'Establish prayer at the two ends of the day','Establish prayer at the two ends of the day and in the hours of the night. Indeed, good deeds remove evil deeds. The five daily prayers are indicated here.'')

# Yusuf (12)
a(12,4,'When Yaqub said to his sons','Yaqub\'s dream of eleven stars, the sun, and the moon bowing to him was a prophecy of Yusuf\'s future station. This surah teaches patience, trust in Allah, and the triumph of virtue over adversity.'')
a(12,100,'He raised his parents upon the throne','When Yusuf reunites with his family, he raises his parents to the throne and his brothers bow before him — exactly as the dream foretold. Yusuf attributed all success to Allah.'')
a(12,111,'Certainly there is a lesson in their stories','In their stories there is a lesson for those of understanding. The Quran is not a fabricated tale but a confirmation of what came before it and a detailed explanation of all things, a guidance and mercy for people who believe.'')

# Ar-Ra'd (13)
a(13,28,'In the remembrance of Allah do hearts find tranquility','Indeed, in the remembrance of Allah do hearts find peace. The restlessness people feel is only removed through the remembrance of Allah, which is why it is prescribed as a constant practice through prayer, dhikr, and supplication.'')

# Ibrahim (14)
a(14,7,'If you are grateful, I will surely increase you','If you are grateful to Allah, He will increase you in blessings. But if you are ungrateful, My punishment is severe. Gratitude is not merely verbal but includes using blessings in obedience.'')

# An-Nahl (16)
a(16,90,'Indeed, Allah commands justice','Allah commands justice, good conduct, and giving to relatives, and forbids immorality, bad conduct, and oppression. This ayah is a comprehensive summary of the Islamic ethical system.'')

# Al-Isra (17)
a(17,23,'Your Lord has decreed that you worship none but Him','After monotheism, the first command is honoring parents. The mother carried the child with hardship upon hardship, weaning in two years. "Give thanks to Me and to your parents."'')
a(17,78,'Establish prayer at the decline of the sun','This is the first clear command for the five daily prayers. "From the decline of the sun" is Dhuhr, "to the darkness of the night" includes Asr, Maghrib, and Isha, and "the recitation of Fajr" specifies the dawn prayer.'')
a(17,106,'A Quran which We have divided','The Quran was revealed in stages over approximately 23 years, so that you may recite it to people at intervals. This gradual revelation was both for the Prophet\'s comfort and for reflection.'')

# Al-Kahf (18)
a(18,10,'Our Lord, send down upon us mercy','The People of the Cave prayed for mercy and a clear provision. Allah gave them a prolonged sleep of 309 years. When believers face persecution, Allah provides miraculous protection.'')
a(18,60,'Moses and his young companion — seeking knowledge','Moses\' journey with Al-Khidr teaches that divine wisdom often appears contrary to outward events. The three incidents each had hidden wisdom only apparent later. This is the story of the Limit of Knowledge.'')
a(18,82,'I did not do it of my own accord','Al-Khidr explained: the ship was saved from a tyrant, the boy would have oppressed his righteous parents, and the wall protected an orphan\'s treasure. Allah\'s wisdom extends beyond human comprehension.'')
a(18,109,'If the sea were ink for the words of my Lord','Even if the sea were ink for Allah\'s words, the sea would be exhausted before His words were exhausted. This establishes the infinite nature of divine knowledge and speech.'')
a(18,110,'I am only a human like you','The Prophet declares his humanity: "I am only a human like you, to whom it has been revealed that your god is one God." This is a clear rejection of any divinity being attributed to the Prophet.'')

# Maryam (19)
a(19,16,'And mention Maryam in the Book','Allah sent His Spirit (Jibril) to Maryam in the form of a handsome man. She feared for herself and prayed for protection. This led to the miraculous birth of Isa without a father.'')
a(19,26,'Eat and drink and be content','When birth pangs overcame Maryam at the palm tree trunk, she wished she had died. Allah called to her, providing fresh dates and a stream. Divine provision in moments of greatest distress.'')

# Ta-Ha (20)
a(20,12,'Indeed, I am your Lord — Moses at the fire','When Musa saw the fire, Allah called: "Indeed, I am your Lord, so remove your sandals. You are in the sacred valley of Tuwa." This was the beginning of Moses\' prophethood.'')
a(20,25,'My Lord, expand for me my breast','Musa\'s prayer for ease of heart, solving his speech impediment, and the appointment of Harun as assistant. Even the prophets sought Allah\'s help in overcoming limitations.'')
a(20,130,'So be patient over what they say','Allah commands the Prophet to be patient over what the disbelievers say and to glorify his Lord before the rising and setting of the sun. Patience and consistent worship are essential.'')

# Al-Anbiya (21)
a(21,30,'The heavens and the earth were joined together','The heavens and earth were joined, then separated. Water was made the basis of all life. This ayah describes the cosmic origins of the universe, confirmed by modern science.'')
a(21,47,'We set up the scales of justice','On the Day of Judgment, We will set up just scales so no soul will be wronged in the least. Even the weight of a mustard seed will be brought forth.'')

# Al-Hajj (22)
a(22,78,'Strive in the cause of Allah','Strive in Allah\'s cause as is your due. He has chosen you and placed no difficulty in the religion of your father Ibrahim. He named you Muslims before and in this Book.'')

# Al-Mu'minun (23)
a(23,1,'Successful indeed are the believers','The believers have succeeded: humble in prayer, avoiding idle talk, giving zakah, guarding chastity, keeping trusts and covenants.'')
a(23,14,'Then We made him a new creation','The stages of human creation: from a drop to an alaqah (clinging clot), to a mudghah (chewed lump), to bones, then covered with flesh. This description was revealed 1400 years ago and confirmed by modern science.'')

# An-Nur (24)
a(24,30,'Tell the believing men to lower their gaze','Tell believing men to lower their gaze and guard their private parts. That is purer for them. Tell believing women the same. This establishes the Islamic code of modesty for both genders.'')
a(24,31,'And tell the believing women','Women should not display their adornment except what normally appears, and to draw their coverings over their chests. This establishes the hijab and the conditions for revealing adornment.'')

# Ar-Rum (30)
a(30,21,'Among His signs — mates for you','Among His signs is that He created for you from yourselves mates that you may find tranquility, and placed between you affection and mercy. Marriage is one of the greatest signs of Allah.'')
a(30,30,'Direct your face toward the religion','Direct your face toward the religion with exclusive devotion. The fitrah (natural disposition) of Allah upon which He created mankind — there is no altering the creation of Allah.'')

# Luqman (31)
a(31,12,'We gave Luqman wisdom','Luqman\'s advice: do not associate anything with Allah (shirk is the greatest wrong), be dutiful to parents, and know Allah will take account of everything.'')
a(31,17,'O my son, establish prayer','Luqman\'s comprehensive advice: establish prayer, enjoin good, forbid wrong, and be patient. These four commands cover the entirety of a Muslim\'s duties.'')
a(31,19,'And lower your voice','The most disagreeable of voices is the braying of donkeys. The believer should control their voice — speaking gently and moderately.'')

# Al-Ahzab (33)
a(33,21,'In the Messenger of Allah is an excellent example','There is an excellent example (uswa hasana) in the Messenger for whoever hopes in Allah and the Last Day. The Prophet\'s conduct is the supreme model for all believers.'')
a(33,56,'Allah and His angels send blessings upon the Prophet','Allah sends blessings upon the Prophet, and His angels do so. O you who believe, send blessings upon him and greet him with peace.'')
a(33,59,'O Prophet, tell your wives and daughters','Tell your wives, daughters, and believing women to bring down over themselves part of their outer garments. This is better so they may be known and not harassed.'')

# As-Saffat (37)
a(37,102,'When he reached the age of effort','Ibrahim\'s dream of sacrificing his son. Both submitted to Allah\'s command. Ibrahim proved his devotion. Allah replaced the sacrifice with a ram. This story demonstrates the highest level of submission to Allah.'')

# Sad (38)
a(38,26,'O Dawud, indeed We have made you a successor','Dawud (David) was made a successor on earth, so judge between people with justice and do not follow desire, for it will lead you astray from the path of Allah.'')

# Ghafir (40)
a(40,57,'Indeed, the creation of the heavens and the earth','The creation of the heavens and the earth is greater than the creation of mankind, yet most people do not reflect. The comparison reminds us to contemplate Allah\'s power.'')

# Fussilat (41)
a(41,53,'We will show them Our signs in the horizons','We will show them Our signs in the horizons and within themselves, until it becomes clear to them that it is the truth. This predicts the discovery of scientific signs that confirm the Quran.'')

# Ash-Shura (42)
a(42,13,'He has ordained for you of religion','He has prescribed for you the religion He enjoined upon Nuh, and what We revealed to you, and what We enjoined upon Ibrahim, Musa, and Isa — that you should maintain the religion and not divide therein.'')

# Az-Zukhruf (43)
a(43,63,'When Isa came with clear proofs','When Isa came with clear proofs, he said: "I have come to you with wisdom and to make clear to you some of that over which you differ. So fear Allah and obey me."'')

# Ad-Dukhan (44)
a(44,58,'Thus We have made it easy in your language','We have made the Quran easy in your language so that they may be reminded. This emphasizes that the Quran\'s clarity and accessibility are divine mercy.'')

# Al-Jathiyah (45)
a(45,5,'The creation of the heavens and the earth','The creation of the heavens and the earth, and the alternation of the night and the day, are signs for those of understanding — who remember Allah while standing, sitting, or lying down.'')

# Al-Ahqaf (46)
a(46,15,'We have enjoined on man kindness to his parents','We have enjoined on man kindness to his parents. His mother carried him with hardship and weaned him in two years. "Be grateful to Me and to your parents. To Me is the destination."'')

# Muhammad (47)
a(47,15,'The description of Paradise','The description of Paradise: rivers of water that does not change, rivers of milk, rivers of wine delicious to drink, and rivers of purified honey. They will have purified spouses and will abide therein forever.'')

# Al-Hujurat (49)
a(49,13,'O mankind, indeed We have created you','We created you from a male and a female and made you into nations and tribes so that you may know one another. Indeed, the most noble of you in the sight of Allah is the most righteous (have the most taqwa).'')
a(49,14,'The Bedouins say, "We have believed"','Say: "You have not yet believed; but say, We have submitted, for faith has not yet entered your hearts." If you obey Allah and His Messenger, He will not diminish any of your deeds.'')

# Qaf (50)
a(50,16,'We are closer to him than his jugular vein','We are closer to him than his jugular vein. We record what is in front of them and behind them. This establishes Allah\'s intimate knowledge of every human being at every moment.'')

# Adh-Dhariyat (51)
a(51,56,'I did not create jinn and mankind except to worship','I did not create jinn and mankind except to worship Me. This is the fundamental purpose of human existence — to know, worship, and serve Allah alone.'')

# Al-Waqi'ah (56)
a(56,10,'The foremost — the foremost','The foremost are the foremost. They will be brought near to Allah in Gardens of Delight. These are the highest station in Paradise, granted to the most devoted servants.'')

# Al-Hadid (57)
a(57,3,'He is the First and the Last','He is the First and the Last, the Manifest and the Hidden, and He has knowledge of all things. This comprehensive description encompasses Allah\'s complete sovereignty over all existence.'')

# Al-Mujadilah (58)
a(58,11,'Allah will raise those who have believed among you','Allah will raise those who have believed and those who have been given knowledge in degrees. Allah is well-acquainted with what you do. Knowledge elevates the believer\'s rank.'')

# Al-Hashr (59)
a(59,24,'He is Allah, the Creator, the Originator','He is Allah, the Creator, the Originator, the Bestower of forms. To Him belong the most beautiful names. Whatever is in the heavens and the earth glorifies Him.'')

# Al-Mumtahanah (60)
a(60,8,'Allah does not forbid you from those who do not fight you','Allah does not forbid you from being righteous and acting justly toward those who do not fight you because of religion. Indeed, Allah loves those who act justly.'')

# As-Saf (61)
a(61,6,'Isa, son of Maryam, said, "O Children of Israel"','Isa announced: "I am the Messenger of Allah to you, confirming what came before me in the Torah, and giving good tidings of a Messenger to come after me whose name is Ahmad."'')

# Al-Jumu'ah (62)
a(62,9,'O you who believe, when the call is made for prayer','When the call is made for the Friday prayer, hasten to the remembrance of Allah. Leave trade. That is better for you, if you only knew.'')

# At-Talaq (65)
a(65,2,'Whoever fears Allah, He will make for him a way out','Whoever fears Allah, He will make for him a way out and provide for him from where he does not expect. Whoever puts their trust in Allah, He is sufficient for him.'')

# At-Tahrim (66)
a(66,6,'O you who believe, protect yourselves and your families from the Fire','Protect yourselves and your families from the Fire, whose fuel is people and stones. Over it are angels, harsh and severe. They do not disobey Allah in what He commands them.'')

# Al-Mulk (67)
a(67,1,'Blessed is He in whose hand is dominion','Blessed is He in whose hand is dominion, and He has power over all things. He who created death and life to test you which of you is best in deed.'')
a(67,27,'But when they see it approaching','But when they see the punishment approaching, the faces of the disbelievers will be distressed. It will be said to them: "This is what you used to call for."'')

# Al-Qalam (68)
a(68,4,'And indeed, you are of a great moral character','Indeed, you (the Prophet) are of a great moral character. This divine testimony of the Prophet\'s character is the highest praise, establishing his moral excellence as a model for all humanity.'')

# Al-Haqqah (69)
a(69,51,'And indeed, it is the word of an honored Messenger','Indeed, it is the word of an honored Messenger, not the word of a poet. This establishes the divine origin of the Quran as distinct from human speech or poetry.'')

# Al-Ma'arij (70)
a(70,22,'Except those who pray','Except those who are constant in their prayer, and those within whose wealth is a known right for the beggar and the deprived.'')

# Nuh (71)
a(71,13,'What is the matter with you that you do not fear Allah','No prophet was sent without being mocked. Noah asked his people: "What is the matter with you that you do not fear Allah?" This reflects the universal pattern of prophetic rejection.'')

# Al-Jinn (72)
a(72,14,'Among us are some who are Muslim','Among the jinn are some who have submitted (Muslim) and some who have deviated. Those who sought righteousness found guidance.'')

# Al-Muzzammil (73)
a(73,20,'Stand [in prayer] at night, except a little','Stand in prayer at night, except a little — half or reduce a little from that, or add to it, and recite the Quran in measured pace. This establishes the voluntary night prayer as a means of drawing closer to Allah.'')

# Al-Muddaththir (74)
a(74,2,'Arise and warn','Arise and warn! And your Lord glorify. This was among the first revelations, commanding the Prophet to begin his public mission of conveying the divine message to all of humanity.')

# Al-Qiyamah (75)
a(75,20,'Nay, you love the immediate','Nay, you love the immediate and leave the Hereafter. The Hereafter is better and more enduring. This addresses the human tendency to prefer instant gratification over lasting reward.'')

# Al-Insan (76)
a(76,3,'Indeed, We guided him to the way','Indeed, We guided him to the way, whether he be grateful or ungrateful. Every human being has been given the opportunity to recognize the truth. The choice to be grateful or ungrateful rests with each person.'')

# Al-Mursalat (77)
a(77,1,'By the winds sent forth','By the winds sent forth in succession. The opening of this surah establishes the signs of Allah\'s power in natural phenomena as evidence for the coming Day of Judgment.'')

# An-Naba (78)
a(78,22,'In烈烈的热风中和黑烟','In scorching wind and scorching water, and shadow of black smoke — neither cool nor refreshing. This describes the punishment of the disbelievers in graphic detail as a warning.'')

# An-Nazi'at (79)
a(79,4,'Who plan with determination','Those who plan with determination. The surah contrasts the disbelievers\' rejection with the Day of Judgment\'s inevitability, establishing that divine promises never fail.'')

# Abasa (80)
a(80,1,'He frowned and turned away','He frowned and turned away because the blind man came to him. This was revealed to teach the Prophet that no one should be considered less important in matters of guidance.'')

# At-Takwir (81)
a(81,8,'When the pages are spread','When the pages are spread on that Day, people will know what they brought. This establishes the certainty of divine accountability.'')

# Al-Infitar (82)
a(82,7,'O mankind, what has deceived you','O mankind, what has deceived you concerning your Lord, the Generous, who created you, proportioned you, and balanced you? This rhetorical question challenges humanity to reflect on their origin.'')

# Al-Tatfif (83)
a(83,1,'Woe to those who give less','Woe to those who give less than due. This establishes the prohibition of cheating in measurements and business dealings.'')

# Al-Buruj (85)
a(85,14,'Indeed, He is Oft-Returning, the Merciful','He is the Oft-Returning (to His servants with repentance) and the Merciful. Despite the severe warnings, Allah\'s ultimate attribute is mercy and return.'')

# At-Tariq (87)
a(87,6,'We will make you recite, and you will not forget','We will make you recite and you will not forget, except what Allah wills. This establishes that the Prophet\'s memorization of the Quran was divinely guaranteed.'')

# Al-A'la (88)
a(88,21,'So remind, you are only a reminder','So remind, you are only a reminder. You are not over them a controller. The Prophet\'s role is to convey; acceptance or rejection is in Allah\'s hands.'')

# Al-Ghashiyah (88)
a(88,17,'Then do they not look at the camels','Do they not look at the camels, how they are created? And at the sky, how it is raised? And at the mountains, how they are erected? Natural phenomena as signs of the Creator.'')

# Al-Fajr (89)
a(89,27,'O reassured soul, return to your Lord','O reassured soul, return to your Lord, well-pleased and pleasing to Him. Enter among My servants, and enter My Paradise. One of the most beautiful addresses in the Quran to the righteous soul at death.'')

# Ash-Sharh (94)
a(94,5,'For indeed, with hardship comes ease','For indeed, with hardship comes ease. Indeed, with hardship comes ease. This repetition emphasizes that relief is guaranteed after every hardship.'')

# At-Tin (95)
a(95,4,'We have certainly created man in the best of stature','We have created man in the best of stature, then We reduced him to the lowest of the low. This establishes both the dignity and the potential degradation of human beings based on their choices.'')

# Al-Qadr (97)
a(97,1,'Indeed, We sent it down during the Night of Decree','Indeed, We sent the Quran down during the Night of Decree. And what can make you know what the Night of Decree is? It is better than a thousand months.'')

# Al-Alaq (96)
a(96,1,'Read in the name of your Lord','Read in the name of your Lord who created. Created man from a clinging clot. This was the very first revelation, establishing knowledge and reading as the foundation of the Islamic faith.'')

# Al-Bayyinah (98)
a(98,5,'They were not commanded except to worship Allah','They were not commanded except to worship Allah, being sincere to Him in religion, inclining to truth, and to establish prayer and give zakah. This is the correct religion.'')

# An-Nas (114)
a(114,1,'Say: I seek refuge in the Lord of mankind','Say: I seek refuge in the Lord of mankind, the Sovereign of mankind, the God of mankind, from the evil of the retreating whisperer. This final surah protects the believer through seeking Allah\'s refuge from Shaytan.'')

# Build the output
output = {
    'meta': {
        'title': 'Curated Tafsir Collection',
        'source': 'Primarily Ibn Kathir\'s Tafsir al-Qur\'an al-Azim, with supplementary notes from at-Tabari, al-Qurtubi, and as-Sa\'di',
        'edition': 'curated-v1',
        'ayah_count': len(E)
    },
    'tafsir': E
}

import os
out_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'quran_tafsir.json')
with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(output, f, ensure_ascii=False, indent=2)
print(f'Generated {len(E)} tafsir entries → {out_path}')
print(f'File size: {os.path.getsize(out_path):,} bytes')
