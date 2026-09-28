# PubMed から論文の要旨を集めるスクリプト
# 使い方（このフォルダの中で実行）:
#   TOPICS=data/topics.json python3 scripts/fetch_pubmed.py 6 data/new_papers.json
#   6 = テーマごとに集める本数、data/new_papers.json = 保存先
# ・まとめ研究/くじ引き実験/レビュー、英語、要旨あり、2014年以降、人が対象、に絞って集める
# ・患者・リハビリ・サプリ・ケガなどの論文は検索の段階で外している
# ・一度集めた論文は seen.json に記録され、次からは重複しない
import json,subprocess,sys,time,urllib.parse,xml.etree.ElementTree as ET,os
BASE="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/"
def get(url):
    for i in range(4):
        r=subprocess.run(["curl","-sS","-m","60",url],capture_output=True,text=True)
        if r.returncode==0 and r.stdout.strip(): return r.stdout
        time.sleep(2)
    raise RuntimeError(url)
FILT=' AND ("athletic performance"[mh] OR athletes[mh] OR sports[mh] OR "physical fitness"[mh] OR "motor skills"[mh]) NOT (patients[tiab] OR rehabilitation[tiab] OR surgery[tiab] OR reconstruction[tiab] OR supplement*[tiab] OR caffeine[tiab] OR stroke[tiab] OR obese[tiab] OR obesity[tiab] OR "cerebral palsy"[tiab] OR elderly[tiab] OR "older adults"[tiab] OR injur*[ti] OR pain[ti] OR protocol[ti]) AND ("meta-analysis"[pt] OR "systematic review"[pt] OR "randomized controlled trial"[pt]) AND english[la] AND hasabstract AND 2014:2026[dp] AND humans[mh]'
def search(q,n):
    u=BASE+"esearch.fcgi?db=pubmed&sort=relevance&retmode=json&retmax=%d&term=%s"%(n,urllib.parse.quote(q+FILT))
    return json.loads(get(u))["esearchresult"]["idlist"]
def fetch(ids):
    x=get(BASE+"efetch.fcgi?db=pubmed&retmode=xml&id="+",".join(ids))
    root=ET.fromstring(x); out=[]
    for a in root.findall("PubmedArticle"):
        mc=a.find("MedlineCitation"); art=mc.find("Article")
        pmid=mc.findtext("PMID")
        title="".join(art.find("ArticleTitle").itertext()).strip()
        abs_parts=[]
        for t in art.findall("Abstract/AbstractText"):
            lab=t.get("Label"); txt="".join(t.itertext()).strip()
            abs_parts.append((lab+": " if lab else "")+txt)
        abstract="\n".join(abs_parts)
        au=art.findall("AuthorList/Author")
        first=(au[0].findtext("LastName") or au[0].findtext("CollectiveName") or "") if au else ""
        journal=art.findtext("Journal/Title") or ""
        year=art.findtext("Journal/JournalIssue/PubDate/Year") or (art.findtext("Journal/JournalIssue/PubDate/MedlineDate") or "")[:4]
        doi=""
        for e in a.findall("PubmedData/ArticleIdList/ArticleId"):
            if e.get("IdType")=="doi": doi=e.text
        pts=[p.text for p in art.findall("PublicationTypeList/PublicationType")]
        out.append(dict(pmid=pmid,title=title,first_author=first,n_authors=len(au),journal=journal,year=year,doi=doi,pub_types=pts,abstract=abstract))
    return out
topics=json.load(open(os.environ.get("TOPICS","topics.json")))
N=int(sys.argv[1]) if len(sys.argv)>1 else 6
seen=set(json.load(open("seen.json"))) if os.path.exists("seen.json") else set()
allp=[]
for field,theme,q in topics:
    try: ids=search(q,N*2)
    except Exception as e: print("ERR",theme,e); continue
    ids=[i for i in ids if i not in seen][:N]
    if not ids: continue
    time.sleep(0.8)
    got=None
    for k in range(4):
        try: got=fetch(ids); break
        except Exception as e: print("retry",theme,e); time.sleep(4)
    if got is None: continue
    for p in got:
        if len(p["abstract"])<400: continue
        p["field"]=field; p["theme"]=theme
        allp.append(p); seen.add(p["pmid"])
    time.sleep(0.8)
    print(theme,len(ids))
json.dump(allp,open(sys.argv[2] if len(sys.argv)>2 else "data/new_papers.json","w"),ensure_ascii=False,indent=1)
json.dump(sorted(seen),open("seen.json","w"))
print("TOTAL",len(allp))
